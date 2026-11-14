function results = run_tests()
%RUN_TESTS Run OX_ARPES synthetic regression tests.
    testsFolder = fileparts(mfilename('fullpath'));
    suite = testsuite(testsFolder,'IncludeSubfolders',true);
    results = run(suite);
    if any([results.Failed])
        error('OxArpes:TestsFailed','One or more OX_ARPES tests failed.');
    end
end
