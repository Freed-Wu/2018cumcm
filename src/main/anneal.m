clear;
clc;
%%%%%%%%%%%%%%%%%%%%%%%%%%寻找最优刀具%%%%%%%%%%%%%%%%%%%%
tic
output_old = 0;
for i = 1:254
	count = dec2bin(i);
	for j = 1:8
		if j <= length(count)
			kind(j) = str2double(count(j));
		else
			kind(j) = 2;
		end
	end
	for j = 1:8
		if kind(j) == 0
			kind(j) = 2;
		end
		
	end
	%双刀的时候选刀具要与下面的静态效果保持一致，电梯最优
	[input, output, time, up, down, CNCfault, STARTfault, ENDfault, input1, input1up, input1down, input2, input2up, input2down] = main4anneal(1, 2, 0, 2, 3, 0, 0, 0, kind);
	if output>output_old
		output_old = output;
		kind_result = kind;
	end
end
kind = kind_result;
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%5
% 参数
number = 40; %迭代次数
maxmum = 0;
interation = 20;
%输入&输出
[input, output, time, up, down, CNCfault, STARTfault, ENDfault, input1, input1up, input1down, input2, input2up, input2down] = main4anneal(1, 3, 0, 2, 3, 0, 0, 0, kind);
%[input, output, time, up, down] = main8(3, 1, 0, 2, 0, 0, 0);
up_initial = up;
down_initial = down;

input_initial = input;
output_initial = output;
time_initial = time
input1_initial = input1;
input1up_initial = input1up;
input1down_initial = input1down;
input2_initial = input2;
input2up_initial = input2up;
input2down_initial = input2down;
output_old = output;
% if order == 1
% for inter = 1:10
input_now = input;
for j = 1:interation
	input = input_initial;
	t0 = 100; %初始温度
	a = 0.7; %衰减系数
	input_now = input;
	for i = 1:number
		input = input_now;
		while 1
			flag_order = fix(1 + (length(input))*rand);
			if flag_order~= 1 && flag_order~= 2;
				break;
			end
		end
		input(flag_order) = fix(1 + 7 * rand);
		%      input = [input; mod(input(length(input)) + 1, 1)];
		[input, output, time, up, down, CNCfault, STARTfault, ENDfault, input1, input1up, input1down, input2, input2up, input2down] = main4anneal(1, 1, 0, 1, 3, input, 1, flag_order, kind);
		%[input, output, time, up, down] = main8(3, 1, 0, 1, input, 1, flag_order);
		
		if output<output_old
			if rand<exp(-(double(output_old - output)) / t0)
				output_old = output;
				input_now = input;
			end
		else
			output_old = output;
			input_now = input;
		end
		t0 = t0 * a;
		if maxmum<output
			maxmum = output;
			input_result = input_now;
			up_result = up;
			down_result = down;
			time_result = time;
			CNCfault_result = CNCfault;
			STARTfault_result = STARTfault;
			ENDfault_result = ENDfault;
			input1_result = input1;
			input1up_result = input1up;
			input1down_result = input1down;
			input2_result = input2;
			input2up_result = input2up;
			input2down_result = input2down;
		end
		
		
	end
	
	
end
toc
% end



disp('服务成功的物料总数');
disp(output);
disp('实际用时');
disp(time);
