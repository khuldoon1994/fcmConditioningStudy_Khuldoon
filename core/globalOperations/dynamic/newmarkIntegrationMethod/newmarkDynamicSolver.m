function [ solutionQuantities ] = newmarkDynamicSolver(problem, solutionPointer, globalMatrices, globalInitialValues)
%calculate solution quantities with the Newmark Integration Method
    
    nTimeSteps = problem.dynamics.nTimeSteps;
    nQuantities = numel(solutionPointer);
    
    % initialize solution quantities and quantity location vectors
    solutionQuantities = cell(size(solutionPointer));
    allLq = cell(size(solutionPointer));
    
    for iQuantity = 1:nQuantities
        currentPointer = solutionPointer{iQuantity};
        quantityLocationVector = currentPointer{2};
        % create quantitylocation vector
        allLq{iQuantity} = goCreateQuantityLocationVector(problem, quantityLocationVector);
        % initialize solution quantities
        solutionQuantities{iQuantity} = zeros(length(allLq{iQuantity}), nTimeSteps);
    end
    
    % extract matrices and vectors from globalMatrices
    M = globalMatrices{1};
    D = globalMatrices{2};
    K = globalMatrices{3};
    F = globalMatrices{4};
    
    % extract initial values from globalInitialValues
    U0Dynamic = globalInitialValues{1};
    V0Dynamic = globalInitialValues{2};
    A0Dynamic = globalInitialValues{3};
    
    % compute penalty stiffness matrix and load vector
    [ Kp, Fp ] = goCreateAndAssemblePenaltyMatrices(problem);
    
    % initialize values
    [ UDynamic, VDynamic, ADynamic ] = newmarkInitialize(problem, U0Dynamic, V0Dynamic, A0Dynamic);
    
    % create effective system matrices
    [ KEff ] = newmarkEffectiveSystemStiffnessMatrix(problem, M, D, K);
    
    % ... and add penalty constraints
    KEff = KEff + Kp;
    
    for iTimeStep = 1:nTimeSteps
        
        % extract necessary quantities from solution
        for iQuantity = 1:nQuantities
            currentPointer = solutionPointer{iQuantity};
            quantityName = currentPointer{1};
            QuantityDynamic = goChooseQuantity(UDynamic, VDynamic, ADynamic, quantityName);
            solutionQuantities{iQuantity}(:, iTimeStep) = QuantityDynamic(allLq{iQuantity});
        end
        
        % calculate effective force vector
        [ FEff ] = newmarkEffectiveSystemForceVector(problem, M, D, K, F, UDynamic, VDynamic, ADynamic);
        
        % and add penalty constraints
        FEff = FEff + Fp;
        
        % solve linear system of equations (UNewDynamic = KEff \ FEff)
        UNewDynamic = moSolveSparseSystem( KEff, FEff );
        
        % calculate velocities and accelerations
        [ VNewDynamic, ANewDynamic ] = newmarkVelocityAcceleration(problem, UNewDynamic, UDynamic, VDynamic, ADynamic);
        
        % update kinematic quantities
        [ UDynamic, VDynamic, ADynamic ] = newmarkUpdateKinematics(UNewDynamic, VNewDynamic, ANewDynamic);
        
    end
    
end
