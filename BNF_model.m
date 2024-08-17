clc,clear all
cd("2_ML model\")
datapath = {'\1_Data\SNFdata_extract.csv','\1_Data\FNFdata_extract.csv'};
VarName = {'SNF','FNF'};
%% ------- RF model ------- %%
% -*- coding: GBK -*-
% Created on Aug 20 2024 by Jiaqiang Liao
% To create the final SNF and FNF maps, we used an ensemble approach,  
% whereby we averaged the global predictions from the 100 best random-forest models 
% based on our bootstrap procedure.

Variable_Name = {'MAT','MAT_season','MAP','MAP_season','AI','AET','VPD','srad','tmax','tmin',...
    'CEC','BD','pH','Sand','Silt','Clay','SWC','SOC','TN','TP',...
    'MBC','MBN','FB_ratio','NPP','BNPP','NDVI','Ndep',...
    'LDMC','SLA_MODIS','LNC_MODIS','LPC_MODIS','Vcmax','fLNR',...
    'EM_tree','AM_tree'};
Variable_Name = string(Variable_Name)';
variablesNum = height(Variable_Name);

pool = gcp('nocreate');
if isempty(pool)
    pool = parpool();
end

% SNF-datapath{1}, FNF-datapath{2}
BNF_ob = readtable(datapath{1});
BNF = table2array(BNF_ob);

BNF = fillmissing(BNF,"movmean",235);
X = BNF(:,5:39);
Y = log(BNF(:,4));

%% initial model trian
for i = 1:100
    % 80% train data 20% test data
    cv = cvpartition(size(X, 1), 'HoldOut', 0.2);
    idxTrain = training(cv);
    Xtrain = X(idxTrain,:);
    ytrain = Y(idxTrain,:);
    Xtest = X(~idxTrain,:);
    ytest = Y(~idxTrain,:);

    % model train
    numTrees = 50;
    RFModel = TreeBagger(numTrees, Xtrain, ytrain, 'Method', 'regression','OOBPredictorImportance','on');

    % model test
    ypred1 = predict(RFModel, Xtest);
    mse = mean((ytest - ypred1).^2);
    rsquared = 1 - mse/var(ytest);

    r2(i,2) = rsquared;
    r2(i,1) = i;

    disp(['run: ', num2str(i)]);
    disp(['R-squared: ', num2str(rsquared)]);

    % variable importance
    importance = RFModel.OOBPermutedPredictorDeltaError;
    [~,idx] = sort(importance,'descend');
    numFeatures = 10;
    selectedFeatures(i,:) = idx(1:numFeatures);
    VarIm(i,:) = RFModel.OOBPermutedPredictorDeltaError;

end

[maxValue, index] = max(r2(:,2))

% top 10 drivers
[counts,binEdges] = histcounts(selectedFeatures);
[sortedCounts, idx] = sort(counts, 'descend');
Features = idx(1:10)

bestModels = cell(100, 1);
bestR2s = zeros(100, 1);

tic;    % 开始计时
parfor j = 1:100
    bestR2 = -inf;
    bestModel = []; 

    for i = 1:100
        % 80% train data 20% test data
        cv = cvpartition(size(X, 1), 'HoldOut', 0.2);
        idxTrain = training(cv);
        Xtrain = X(idxTrain,:);
        ytrain = Y(idxTrain,:);
        Xtest = X(~idxTrain,:);
        ytest = Y(~idxTrain,:);

        % model train
        numTrees = 50;
        RFModelSelected = TreeBagger(numTrees, Xtrain(:, Features), ytrain, ...
            'Method', 'regression','OOBPredictorImportance','on');

        % model test
        ypred2 = predict(RFModelSelected, Xtest(:, Features));
        mse = mean((ytest - ypred2).^2);
        rsquared = 1 - mse/var(ytest);

        if rsquared > bestR2
            bestR2 = rsquared;
            bestModel = RFModelSelected;
        end
    end

    bestModels{j} = bestModel;
    bestR2s(j) = bestR2;

    disp(['Best R-squared for iteration ', num2str(j), ': ', num2str(bestR2)]);
end
toc;

% find best R-squared and models
[maxR2, maxIndex] = max(bestR2s);
bestModel = bestModels{maxIndex};
disp(['Best overall R-squared: ', num2str(maxR2)]);
disp(['Index of best model: ', num2str(maxIndex)]);

%% model performance
Y_trained = bestModel.Y;
X_trained = bestModel.X;
Y_predicted = predict(bestModel,X_trained);

figure()
scatter(Y_trained ,Y_predicted, 'o', ...
    'MarkerEdgeColor', 'k', 'SizeData', 50,'LineWidth', 1);
axis square
box on;
hold on;
xlim = get(gca, 'XLim');
line([xlim(1), xlim(2)], [xlim(1), xlim(2)], 'Color', 'k', 'LineStyle', ':','LineWidth',2);
hold off;
cor = corr(Y_trained ,Y_predicted);
% intercept = p(2)；
title_str = [VarName{1},' Model Performance'];
title(title_str,'FontSize',14);
ylabel('Predicted Value (ln, kg ha^-^1 yr^-^1)','FontSize',12,'FontName','Times');
xlabel('Observed Value (ln, kg ha^-^1 yr^-^1)','FontSize',12,'FontName','Times');
legend(num2str(maxR2), '1:1 Line', 'Location', 'northwest');
set(gca,'FontName','Times');
grid on;

%  R suqare histogram
mapdata = bestR2s;
histogram(mapdata,'FaceAlpha',0.8)
xlabel('R^2');ylabel('Counts')
title(VarName{1})
set(gca, 'FontName', 'Times', 'FontSize', 15)

%% model predict
load X_predict(35)_inter.mat
load Landcover_2020.mat
load mycolor.mat

% 变量名
Variable_Name = {'MAT','MAT_season','MAP','MAP_season','AI','AET','VPD','srad','tmax','tmin',...
    'CEC','BD','pH','Sand','Silt','Clay','SWC','SOC','TN','TP',...
    'MBC','MBN','FB_ratio','NPP','BNPP','NDVI','Ndep',...
    'LDMC','SLA_MODIS','LNC_MODIS','LPC_MODIS','Vcmax','fLNR',...
    'EM_tree','AM_tree'};
Variable_Name = string(Variable_Name)';
variablesNum = height(Variable_Name);

varNames = Variable_Name(Features);

predict_X = zeros(length(eval(varNames{1})), length(varNames));

for i = 1:length(varNames)
    predict_X(:, i) = eval(varNames{i});
end

Y_predict_all = zeros(size(predict_X, 1), 100);

% 100 models precit
tic;
parfor j = 1:100
    Y_predict = predict(bestModels{j}, predict_X);
    Y_predict_all(:, j) = Y_predict;
end
toc;

%% average (100 runs)
Y_predict_sum = sum(Y_predict_all,2);
Y_predict_avg = Y_predict_sum/100;

Y_predict_std = std(Y_predict_all, 0, 2);
Y_predict_std = reshape(Y_predict_std,[360,720]);

anss = prctile(Y_predict_avg ,[5,95],'all')
meanY = mean(Y_predict_avg,"all","omitnan");

Y_predict_avg = reshape(Y_predict_avg,[360,720]);
Y_predict_avg(Landcover_2020 <1 | Landcover_2020 >14) = nan;
histogram(Y_predict_avg)

BNF_cv = Y_predict_std./Y_predict_avg;

Y_predict_avg = exp(Y_predict_avg);
histogram(Y_predict_avg)

BNF_predict = Y_predict_avg;
