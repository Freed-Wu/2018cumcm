function[input, output, time, up, down, CNCfault, STARTfault, ENDfault, input1, input1up, input1down, input2, input2up, input2down] = main4anneal(order, stepMax, fault, dispatch, algorithm, input, flag, flag_order, kind)
flag_fault = 1;
CNCfault = 0;
STARTfault = 0;
ENDfault = 0;
input1 = 0;
input1up = 0;
input1down = 0;
input2 = 0;
input2up = 0;
input2down = 0;

%输入参数
%order 组号 stepMax 工序 fault 错误率（1 - 100）dispatch调度必须是1：不调度（随机）；2：静态；3：动态（最短作业）！
%algorithm = 静态调度算法必须是1：先来先服务 + 最短路径优先；2：最短路径优先；3：电梯扫描；4：循环电梯扫描；5：先来先服务 + 静态优先级；6：静态优先级！
% input输入的顺序 flag是否采用字符 flag_order模拟退火改变次序的初值kind当双刀时的道具顺序


level = zeros(8, 1, 'int32');


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
if flag == 0
	input = zeros(inputNumber, 1);
else
	input = [input; ones(length(input), 1)];
end
output = int16(0);
up = zeros(inputNumber, 1);
down = zeros(inputNumber, 1);
downUp = zeros(inputNumber, 1);
%默认移动方向以向右为正方向
orient = 1;

%不调度，生成随机输入
% if dispatch == 1
% for n = 1:inputNumber
% inputCome0 = find(kind == step);
% 		kindNumber = length(inputCome0);
% 		indexInputCome0 = 1 + fix(kindNumber*rand);
% 		input(n) = inputCome0(indexInputCome0);
% 		if step == stepMax
% step = 1;
% 		else
% 			step = step + 1;
% 		end
% 	end
% end

for n = 1:length(input)
	if n == flag_order
		algorithm = 2;
	end
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
				case 5 % 先来先服务 + 默认优先级
					% 第一轮筛选：冷却完成且最先冷却完成
					inputCome = inputCome0(priority(inputCome0) == min(priority(inputCome0)));
					%第二轮筛选：默认优先级
					inputCome2 = inputCome(level(inputCome) == max(level(inputCome)));
				case 6 % 默认优先级
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
	
	if dispatch == 2 || dispatch == 1
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
	if dispatch == 2 || dispatch == 1
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
				input2(output + 1) = inputServe;
				input2up(output + 1) = up(n);
				
				down(n) = time + timeBlock + timeWait + timeMove + timeReady + timeUpdate + timeClean;
				input2down(output + 1) = down(n);
				%下轮迭代仍可输出熟料
				% 				if cnc(kind == stepMax) -
				output = output + 1;
				step = 1;
			else
				timeClean = 0;
				input1(output + 1) = inputServe;
				input1up(output + 1) = up(n);
				input1down(output + 1) = up(n) + machine(inputServe);
				%输出不变
				%下轮迭代仍可输出半熟料
				step = step + 1;
			end
		else
			timeClean = 0;
			%输出不变
			isOutputable(inputServe) = 1;
			%                 input1(output + 1) = inputServe;
			%                 input1up(output + 1) = up(n);
			%                 input1down(output + 1) = up(n) + machine(inputServe);
			if step == stepMax
				step = 1;
			end
		end
	end
	if dispatch == 2 || dispatch == 1
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
		% 		for k = find(down, 1) :length(down)
		% downUp(k + 1 - find(down, 1)) = down(U;; p);
		% 		end
		break;
	end
	cnc = cnc - timeRgv;
	priority = cnc; %保存先后次序
	cnc = max(0, cnc);
	% 	look = [reshape(cnc, 2, 4), [time, time - look(1, 5); posit, n]]
end
disp('实际用时');
disp(time);
% disp('服务次序');
% disp(input');
% disp('上料时间');
% disp(up');
% disp('下料时间');
% disp(down');
disp('服务成功的物料总数');
disp(output);
end
