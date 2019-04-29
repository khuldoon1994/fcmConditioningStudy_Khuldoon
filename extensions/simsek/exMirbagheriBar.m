% In SiHoFemLab, the problem definition is stored in a structure.
% In this script, the following problem will be defined:
%
%                        f(x)
%   /|---> ---> ---> ---> ---> ---> ---> --->
%   /|=======================================
%   /|          E,A,rho,kappa,L
%
% A bar, characterized by its Youngs modulus E, area A,
% mass density rho, damping coefficient kappa and length L
% is loaded by a distributed force (one-dimensional "body-force").
%
% This elastodynamic problem will be analyzed using
% Central Difference Method

%% clear variables, close figures
clear all;
close all;
clc;
warning('off', 'MATLAB:nearlySingularMatrix'); % get with [a, MSGID] = lastwarn();

%% problem definition
problem.name = 'dynamicBar1D (Central Difference Method)';
problem.dimension = 1;

% volume load
f = @(x) 0;

% static parameters
% static parameters
E = 70e9;
A = 0.0006;
L = 20.0;

% dynamic parameters
rho = 2700/A;              % mass density
alpha = 0.0;               % damping coefficient
kappa = rho * alpha;

p = 1;
n = 200;

tStart = 0;
tStop = 5;
nTimeSteps = 401;

% create problem
problem = poCreateDynamicBarProblem(E, A, rho, kappa, L, p, n, f, tStart, tStop, nTimeSteps);

% initialize dynamic problem
problem = poInitializeDynamicProblem(problem);


%% dynamic analysis
% create system matrices
[ allMe, allDe, allKe, allFe, allLe ] = goCreateDynamicElementMatrices( problem );

% assemble
M = goAssembleMatrix(allMe, allLe);
D = goAssembleMatrix(allDe, allLe);
K = goAssembleMatrix(allKe, allLe);
F = goAssembleVector(allFe, allLe);

% set initial displacement and velocity
[ nTotalDof ] = goNumberOfDof(problem);
UDynamic = zeros(nTotalDof, 1);
VDynamic = zeros(nTotalDof, 1);

% compute initial acceleration
[ ADynamic ] = goComputeInitialAcceleration(problem, M, D, K, F, UDynamic, VDynamic);

% initialize values
[ UOldDynamic, UDynamic ] = cdmInitialize(problem, UDynamic, VDynamic, ADynamic);

% create effective system matrices
[ KEff ] = cdmEffectiveSystemStiffnessMatrix(problem, M, D, K);

% post processing stuff
indexOfLastNode = n+1;
displacementAtLastNode = zeros(problem.dynamics.nTimeSteps, 1);
velocityAtLastNode = zeros(problem.dynamics.nTimeSteps, 1);
displacementAtAllNodes = zeros(indexOfLastNode,problem.dynamics.nTimeSteps);
% time loop
for timeStep = 1 : problem.dynamics.nTimeSteps
    
    disp(['time step ', num2str(timeStep)]);
    fflush(stdout);
    
    % extract necessary quantities from solution
    displacementAtLastNode(timeStep) = UDynamic(indexOfLastNode);
    velocityAtLastNode(timeStep) = VDynamic(indexOfLastNode);
    displacementAtAllNodes(:,timeStep) = UDynamic;
    
    % calculate effective force vector
    [ FEff ] = cdmEffectiveSystemForceVector(problem, M, D, K, F, UDynamic, UOldDynamic);
       
    if(timeStep==100)
       FEff(indexOfLastNode) = FEff(indexOfLastNode) + 1000;
    end
    
    % solve linear system of equations
    UNewDynamic = moSolveSparseSystem( KEff, FEff );
    
    % calculate velocities and accelerations
    [ VDynamic, ADynamic ] = cdmVelocityAcceleration(problem, UNewDynamic, UDynamic, UOldDynamic);
    
    % update kinematic quantities
    [ UDynamic, UOldDynamic ] = cdmUpdateKinematics(UNewDynamic, UDynamic);
    
end


%% post processing
timeVector = goGetTimeVector(problem);

% plotting necessary quantities over time
figure(1);

subplot(1,2,1)
plot(timeVector, displacementAtLastNode, '-');
title('Displacement at last node');
xlabel('Time [s]');
ylabel('Displacement [m]');


subplot(1,2,2)
plot(timeVector, velocityAtLastNode, '-');
title('Velocity at last node');
xlabel('Time [s]');
ylabel('Velcoity [m/s]');


for i=1:nTimeSteps
figure(2);
%plot(L,displacementAtLastNode(i))
plot(problem.nodes,displacementAtAllNodes(:,i))
axis ([0,L,min(min(displacementAtAllNodes)), max(max(displacementAtAllNodes))])
pause(0.001)
end