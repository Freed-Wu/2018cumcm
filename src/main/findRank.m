function[outputMax, timeMin] = findRank(varargin)
tic
parser = inputParser;

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
algorithmError = '静态调度算法必须是1：先来先服务+最短路径优先；2：最短路径优先；3：电梯扫描；4：循环电梯扫描；5：先来先服务+静态优先级；6：静态优先级！默认是5！';
algorithmValidat = @(x)assert(x == 1 || x == 2 || x == 3 || x == 4 || x == 5 || x == 6, algorithmError);
addOptional(parser, 'algorithm', 6, algorithmValidat);

kindError = '默认是[1;2;2;1;2;1;1;2]！';
kindValidat = @(x)assert(length(x) == 8 && min(x) == 1 && max(x) == 2, kindError);
addOptional(parser, 'kind', [1; 2; 2; 1; 2; 1; 1; 2]);

parse(parser, varargin{ : });
order = parser.Results.order;
stepMax = parser.Results.stepMax;
fault = parser.Results.fault;
dispatch = parser.Results.dispatch;
algorithm = parser.Results.algorithm;

kind = parser.Results.kind;

outputMax = 0;
timeMin = 0;
ranks = perms(1:8);
sizeRanks = size(ranks);
for n = 1:sizeRanks(1, 1)
	disp('剩余穷举总数');
	disp(sizeRanks(1, 1) - n);
	rank = ranks(n, :)';
	[output, time] = main(order, stepMax, fault, dispatch, algorithm, rank, kind);
	if output>outputMax || (output == outputMax && time<timeMin)
		rankBest = rank;
		outputMax = output;
		timeMin = time;
	end
	clc;
end
disp('最佳静态优先级排序');
disp(rankBest');
disp('服务成功的物料总数的最大值');
disp(outputMax);
disp('对应的用时');
disp(timeMin);
disp('程序运行用时');
disp(toc);
end
