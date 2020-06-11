function[output, time] = main100(varargin)
flag_fault = 1;
look = zeros(2, 6); %调试查看的中间变量
parser = inputParser;
CNCfault = 0;
STARTfault = 0;
ENDfault = 0;

orderError = '组号必须是1或2或3！默认是1！';
orderValidat = @(x)assert(x == 1 || x == 2 || x == 3, orderError);
addOptional(parser, 'order', 1, orderValidat);
stepMaxError = '加工步骤数必须是1或2！默认是1！';
stepMaxValidat = @(x)assert(x == 1 || x == 2, stepMaxError);
addOptional(parser, 'stepMax', 1, stepMaxValidat);
faultError = '故障发生百分率必须是不超过100的非负数！默认是0！';
faultValidat = @(x)assert((x >= 0) && (x <= 100) && isnumeric(x) && isscalar(x), faultError);
addOptional(parser, 'fault', 0, faultValidat);
dispatchError = '调度必须是1：不调度（随机）；2：静态；3：动态（最短作业）！默认是2！';
dispatchValidat = @(x)assert(x == 1 || x == 2 || x == 3, dispatchError);
addOptional(parser, 'dispatch', 2, dispatchValidat);
algorithmError = '静态调度算法必须是1：先来先服务+最短路径优先；2：最短路径优先；3：电梯扫描；4：循环电梯扫描；5：先来先服务+静态优先级；6：静态优先级！默认是1！';
algorithmValidat = @(x)assert(x == 1 || x == 2 || x == 3 || x == 4 || x == 5 || x == 6, algorithmError);
addOptional(parser, 'algorithm', 3, algorithmValidat);
rankError = '默认是[2;4;6;8;7;5;3;1]！';
rankValidat = @(x)assert(length(x) == 8 && min(any(x - perms(1:8))) == 0, rankError);
addOptional(parser, 'rank', [2; 4; 6; 8; 7; 5; 3; 1]);
kindError = '默认是[1;2;2;1;2;1;1;2]！';
kindValidat = @(x)assert(length(x) == 8 && min(x) == 1 && max(x) == 2, kindError);
addOptional(parser, 'kind', [1; 2; 2; 1; 2; 1; 1; 2]);

parse(parser, varargin{ : });
order = parser.Results.order;
stepMax = parser.Results.stepMax;
fault = parser.Results.fault;
dispatch = parser.Results.dispatch;
algorithm = parser.Results.algorithm;
rank = parser.Results.rank;
kind = parser.Results.kind;

level = zeros(length(rank), 1, 'int32');
for n = 1:length(rank)
	level(n) = find(rank == n);
end

%参数
data = [20 23	18;
	33	41	32;
	46	59	46;
	560	580	545;
	400	280	455;
	378	500	182;
	28	30	27;
	31	35	32;
	25	30	25];
move = data(1:3, order);
update = zeros(8, 1);
update([1, 3, 5, 7], 1) = data(7, order)*ones(4, 1);
update([2, 4, 6, 8], 1) = data(8, order)*ones(4, 1);
machine = zeros(8, 1);
if stepMax == 1
	kind = ones(8, 1);
	machine(kind == 1) = data(4, order);
else
	machine(kind == 1) = data(5, order);
	machine(kind == 2) = data(6, order);
end
clean = data(9, order)*ones(8, 1);
%服务器
cnc = zeros(8, 1, 'int32');
isOutputable = zeros(8, 1, 'int32');
priority = zeros(8, 1, 'int32');
%位置&时间
timeMax = int32(28800); %$8\times3600 = 28800$
step = 1;
posit = int32(1);
time = int32(0);
%输入&输出
inputNumerRgv = (timeMax + min(clean)) / min(update + clean);
inputNumerCnc = length(cnc)*fix((timeMax - min(update)) / (min(machine + update)));
inputNumber = 2 * min(inputNumerRgv, inputNumerCnc);
input = zeros(inputNumber, 1);
output = int16(0);
up = zeros(inputNumber, 1);
down = zeros(inputNumber, 1);
downUp = zeros(inputNumber, 1);
%默认移动方向以向右为正方向
orient = 1;

%不调度，生成随机输入
if dispatch == 1
	for n = 1:inputNumber
		inputCome0 = find(kind == step);
		kindNumber = length(inputCome0);
		indexInputCome0 = 1 + fix(kindNumber*rand);
		input(n) = inputCome0(indexInputCome0);
		if step == stepMax
			step = 1;
		else
			step = step + 1;
		end
	end
end

for n = 1:length(input)
	if dispatch == 2 || dispatch == 3 % 调度
		%第零轮筛选：工序符合
		inputCome0 = find(kind == step);
		if dispatch == 3 % 动态调度
			%第一轮筛选：最短作业时间优先
			inputCome = inputCome0(cnc(inputCome0) == min(cnc(inputCome0)));
		else%静态调度
			switch algorithm
				case 1 % 先来先服务 + 最短路径优先
					% 第一轮筛选：冷却完成且最先冷却完成
					inputCome = inputCome0(priority(inputCome0) == min(priority(inputCome0)));
					%第二轮筛选：最短路径优先
					positCome = int32(fix((inputCome + 1) / 2));
					distCome = abs(posit - positCome);
					inputCome2 = inputCome(distCome == min(distCome));
				case 2 % 最短路径优先
					%第一轮筛选：冷却完成
					inputCome = inputCome0(cnc(inputCome0) == min(cnc(inputCome0)));
					%第二轮筛选：最短路径优先
					positCome = int32(fix((inputCome + 1) / 2));
					distCome = abs(posit - positCome);
					inputCome2 = inputCome(distCome == min(distCome));
				case 3 % 电梯扫描
					%第一轮筛选：冷却完成
					inputCome = inputCome0(cnc(inputCome0) == min(cnc(inputCome0)));
					%第二轮筛选：跟移动方向相同的优先
					positCome = int32(fix((inputCome + 1) / 2));
					if orient == 1
						distCome = positCome - posit;
					else
						distCome = posit - positCome;
					end
					%如果移动方向都相反
					if max(distCome)<0
						inputCome2 = inputCome(distCome == max(distCome));
						orient = ~orient; %反转移动方向
					else
						inputCome2 = inputCome(distCome == min(distCome));
					end
				case 4 % 循环电梯扫描
					%第一轮筛选：冷却完成
					inputCome = inputCome0(cnc(inputCome0) == min(cnc(inputCome0)));
					%第二轮筛选：跟移动方向相同的优先
					positCome = int32(fix((inputCome + 1) / 2));
					if orient == 1
						distCome = positCome - posit;
					else
						distCome = posit - positCome;
					end
					inputCome2 = inputCome(distCome == min(distCome));
				case 5 % 先来先服务 + 静态优先级
					% 第一轮筛选：冷却完成且最先冷却完成
					inputCome = inputCome0(priority(inputCome0) == min(priority(inputCome0)));
					%第二轮筛选：默认优先级
					inputCome2 = inputCome(level(inputCome) == max(level(inputCome)));
				case 6 % 静态优先级
					%第一轮筛选：冷却完成
					inputCome = inputCome0(cnc(inputCome0) == min(cnc(inputCome0)));
					%第二轮筛选：默认优先级
					inputCome2 = inputCome(level(inputCome) == max(level(inputCome)));
			end
		end
		%第三轮筛选：位置最靠近中心
		positCome2 = fix((inputCome2 + 1) / 2);
		deviatCome2 = abs(positCome2 - 2.5);
		inputCome3 = inputCome2(deviatCome2 == min(deviatCome2));
		%第四轮筛选：上下料时间最短
		updateCome3 = update(inputCome3);
		input(n) = inputCome3(updateCome3 == min(updateCome3));
	end
	inputServe = input(n);
	
	if dispatch == 2
		timeBlock = cnc(inputServe);
	else
		timeBlock = 0;
	end
	timeWait = 0;
	%rgv移动时间
	positServe = fix((inputServe + 1) / 2);
	dist = abs(positServe - posit);
	if dist == 0
		timeMove = int32(0);
	else
		timeMove = move(dist);
	end
	%rgv就绪时间
	if dispatch == 2
		timeReady = 0;
	else
		timeReady = cnc(inputServe) - timeMove;
	end
	%rgv&cnc上下料时间
	timeUpdate = update(inputServe);
	up(n) = time + timeBlock + timeWait + timeMove + timeReady + timeUpdate;
	%cnc加工时间
	%cnc修理时间
	%rgv清洗时间
	%输出
	%下轮迭代可输出标志位
	%工序
	if rand * 100<fault
		timeMachine = rand * machine(inputServe);
		CNCfault(flag_fault) = inputServe;
		STARTfault(flag_fault) = time + timeBlock + timeWait + timeMove + timeReady + timeUpdate + timeMachine;
		timeRepair = 600 + rand * 600;
		ENDfault(flag_fault) = time + timeBlock + timeWait + timeMove + timeReady + timeUpdate + timeMachine + timeRepair;
		flag_fault = flag_fault + 1;
		
		timeClean = 0;
		%输出不变
		isOutputable(inputServe) = 0;
		%工序不变
	else
		timeMachine = machine(inputServe);
		timeRepair = 0;
		if isOutputable(inputServe) == 1
			if step == stepMax
				timeClean = clean(inputServe);
				output = output + 1;
				%下轮迭代仍可输出熟料
				step = 1;
			else
				timeClean = 0;
				%输出不变
				%下轮迭代仍可输出半熟料
				step = step + 1;
			end
			down(n) = time + timeBlock + timeWait + timeMove + timeReady + timeUpdate + timeClean;
		else
			timeClean = 0;
			%输出不变
			isOutputable(inputServe) = 1;
			if step == stepMax
				step = 1;
			end
		end
	end
	if dispatch == 2
		timeQueue = timeWait + timeMove;
	else
		timeQueue = 0;
	end
	%rgv机器周期
	timeRgv = timeBlock + timeWait + timeMove + timeReady + timeUpdate + timeClean;
	%cnc机器周期
	timeCnc = timeQueue + timeUpdate + timeMachine + timeRepair;
	
	%刷新服务器&位置&时间&优先级
	cnc(inputServe) = cnc(inputServe) + timeCnc;
	posit = positServe;
	time = time + timeRgv;
	if time>timeMax
		time = time - timeRgv;
		output = output - 1;
		input = input(1:n - 1);
		up = up(1:n - 1);
		down = down(1:n - 1);
		%整理下料时间
		for m = find(down, 1) :length(down)
			for k = m - 1 : -1 : 1
				if input(k) == input(m)
					downUp(k) = down(m);
					break;
				end
			end
		end
		%第二工序索引
		indexInputStepMax = zeros(output, 1);
		indexInput1 = zeros(output, 1);
		k = 0;
		for m = 1:length(input)
			if kind(input(m)) == stepMax
				k = k + 1;
				indexInputStepMax(k) = m;
			end
			indexInput1 = indexInputStepMax - 1;
		end
		%整理第一工序索引
		for m = 1:length(indexInput1)
			for k = indexInput1(m) - 1 : -1 : 1
				if input(k) == input(indexInput1(m))
					indexInput1(m) = k;
					break;
				end
			end
		end
		break;
	end
	cnc = cnc - timeRgv;
	priority = cnc; %保存先后次序
	cnc = max(0, cnc);
	% 	look = [reshape(cnc, 2, 4), [time, time - look(1, 5); posit, n]]
end
tableSuccess = zeros(length(indexInputStepMax), stepMax * 3);
tableFail = zeros(length(indexInputStepMax), stepMax * 3);
if stepMax == 2
	table = zeros(length(indexInputStepMax), stepMax * 3);
	for n = 1:length(indexInputStepMax)
		table(n, :) = [input(indexInput1(n), 1),
			up(indexInput1(n), 1),
			downUp(indexInput1(n), 1),
			input(indexInputStepMax(n), 1),
			up(indexInputStepMax(n), 1),
			downUp(indexInputStepMax(n), 1)
			];
	end
	for n = 1:length(table)
		% 有故障
		if table(n, 3) == 0 || table(n, 6) == 0
			tableFail(n, :) = table(n, :);
			if tableFail(n, 3) == 0
				tableFail(n, 4:6) = 0;
			end
		else
			tableSuccess(n, :) = table(n, :);
		end
	end
	disp('服务次序，上料时间，下料时间,服务次序，上料时间，下料时间');
else
	table = [input(1:output, : ), up(1:output, : ), downUp(1:output, : )];
	for n = 1:length(table)
		% 有故障
		if table(n, 3) == 0
			tableFail(n, :) = table(n, :);
		else
			tableSuccess(n, :) = table(n, :);
		end
	end
	disp('服务次序，上料时间，下料时间');
end
tableSuccess(all(tableSuccess == 0, 2), :) = [];
tableFail(all(tableFail == 0, 2), :) = [];
disp('正常工作的物料');
disp(tableSuccess);
disp('出现故障的物料');
disp(tableFail);
disp('服务成功的物料总数');
disp(output);
disp('实际用时');
disp(time);
CNCfault = CNCfault';
STARTfault = STARTfault';
ENDfault = ENDfault';
array1 = 1:output;
array1 = array1';
array2 = 1:flag_fault - 1;
array2 = array2';

if stepMax == 1 && fault == 0
	if order == 1
		xlswrite('Case_1_result', array1, '第1组', ['A2:A' num2str(1 + output)]);
		xlswrite('Case_1_result', input, '第1组', ['B2:B' num2str(1 + output)]);
		xlswrite('Case_1_result', up(1:end - 8), '第1组', ['C2:C' num2str(1 + output)]);
		xlswrite('Case_1_result', down(9:end), '第1组', ['D2:D' num2str(1 + output)]);
	elseif  order == 2
		xlswrite('Case_1_result', array1, '第2组', ['A2:A' num2str(1 + output)]);
		xlswrite('Case_1_result', input, '第2组', ['B2:B' num2str(1 + output)]);
		xlswrite('Case_1_result', up(1:end - 8), '第2组', ['C2:C' num2str(1 + output)]);
		xlswrite('Case_1_result', down(9:end), '第2组', ['D2:D' num2str(1 + output)]);
	elseif  order == 3
		xlswrite('Case_1_result', array1, '第3组', ['A2:A' num2str(1 + output)]);
		xlswrite('Case_1_result', input, '第3组', ['B2:B' num2str(1 + output)]);
		xlswrite('Case_1_result', up(1:end - 8), '第3组', ['C2:C' num2str(1 + output)]);
		xlswrite('Case_1_result', down(9:end), '第3组', ['D2:D' num2str(1 + output)]);
	end
	
end
if stepMax == 1 && fault == 1
	if order == 1
		xlswrite('Case_3_result_1', array1, '第1组', ['A2:A' num2str(1 + output - flag_fault * 2)]);
		xlswrite('Case_3_result_1', tableSuccess, '第1组', ['B2:D' num2str(1 + output - flag_fault * 2)]);
		xlswrite('Case_3_result_1', array2, '第1组的故障', ['A2:A' num2str(flag_fault)]);
		xlswrite('Case_3_result_1', CNCfault, '第1组的故障', ['B2:B' num2str(flag_fault)]);
		xlswrite('Case_3_result_1', STARTfault, '第1组的故障', ['C2:C' num2str(flag_fault)]);
		xlswrite('Case_3_result_1', ENDfault, '第1组的故障', ['D2:D' num2str(flag_fault)]);
	elseif order == 2
		xlswrite('Case_3_result_1', array1, '第2组', ['A2:A' num2str(1 + output - flag_fault * 2)]);
		xlswrite('Case_3_result_1', tableSuccess, '第2组', ['B2:D' num2str(1 + output - flag_fault * 2)]);
		xlswrite('Case_3_result_1', array2, '第2组的故障', ['A2:A' num2str(flag_fault)]);
		xlswrite('Case_3_result_1', CNCfault, '第2组的故障', ['B2:B' num2str(flag_fault)]);
		xlswrite('Case_3_result_1', STARTfault, '第2组的故障', ['C2:C' num2str(flag_fault)]);
		xlswrite('Case_3_result_1', ENDfault, '第2组的故障', ['D2:D' num2str(flag_fault)]);
	elseif order == 3
		xlswrite('Case_3_result_1', array1, '第3组', ['A2:A' num2str(1 + output - flag_fault * 2)]);
		xlswrite('Case_3_result_1', tableSuccess, '第3组', ['B2:D' num2str(1 + output - flag_fault * 2)]);
		xlswrite('Case_3_result_1', array2, '第3组的故障', ['A2:A' num2str(flag_fault)]);
		xlswrite('Case_3_result_1', CNCfault, '第3组的故障', ['B2:B' num2str(flag_fault)]);
		xlswrite('Case_3_result_1', STARTfault, '第3组的故障', ['C2:C' num2str(flag_fault)]);
		xlswrite('Case_3_result_1', ENDfault, '第3组的故障', ['D2:D' num2str(flag_fault)]);
	end
end
if stepMax == 2 && fault == 0
	if order == 1
		xlswrite('Case_2_result', array1, '第1组', ['A2:A' num2str(1 + output)]);
		xlswrite('Case_2_result', tableSuccess, '第1组', ['B2:G' num2str(1 + output)]);
	elseif  order == 2
		xlswrite('Case_2_result', array1, '第2组', ['A2:A' num2str(1 + output)]);
		xlswrite('Case_2_result', tableSuccess, '第2组', ['B2:G' num2str(1 + output)]);
	elseif  order == 3
		xlswrite('Case_2_result', array1, '第3组', ['A2:A' num2str(1 + output)]);
		xlswrite('Case_2_result', tableSuccess, '第3组', ['B2:G' num2str(1 + output)]);
	end
	
end
if stepMax == 2 && fault == 1
	if order == 1
		xlswrite('Case_3_result_2', array1, '每1组', ['A2:A' num2str(1 + output)]);
		xlswrite('Case_3_result_2', tableSuccess, '每1组', ['B2:G' num2str(1 + output)]);
		xlswrite('Case_3_result_2', array2, '第1组的故障', ['A2:A' num2str(flag_fault)]);
		xlswrite('Case_3_result_2', CNCfault, '第1组的故障', ['B2:B' num2str(flag_fault)]);
		xlswrite('Case_3_result_2', STARTfault, '第1组的故障', ['C2:C' num2str(flag_fault)]);
		xlswrite('Case_3_result_2', ENDfault, '第1组的故障', ['D2:D' num2str(flag_fault)]);
	elseif  order == 2
		xlswrite('Case_3_result_2', array1, '第2组', ['A2:A' num2str(1 + output)]);
		xlswrite('Case_3_result_2', tableSuccess, '第2组', ['B2:G' num2str(1 + output)]);
		xlswrite('Case_3_result_2', array2, '第2组的故障', ['A2:A' num2str(flag_fault)]);
		xlswrite('Case_3_result_2', CNCfault, '第2组的故障', ['B2:B' num2str(flag_fault)]);
		xlswrite('Case_3_result_2', STARTfault, '第2组的故障', ['C2:C' num2str(flag_fault)]);
		xlswrite('Case_3_result_2', ENDfault, '第2组的故障', ['D2:D' num2str(flag_fault)]);
	elseif  order == 3
		xlswrite('Case_3_result_2', array1, '第3组', ['A2:A' num2str(1 + output)]);
		xlswrite('Case_3_result_2', tableSuccess, '第3组', ['B2:G' num2str(1 + output)]);
		xlswrite('Case_3_result_2', array2, '第3组的故障', ['A2:A' num2str(flag_fault)]);
		xlswrite('Case_3_result_2', CNCfault, '第3组的故障', ['B2:B' num2str(flag_fault)]);
		xlswrite('Case_3_result_2', STARTfault, '第3组的故障', ['C2:C' num2str(flag_fault)]);
		xlswrite('Case_3_result_2', ENDfault, '第3组的故障', ['D2:D' num2str(flag_fault)]);
	end
	
end

end
