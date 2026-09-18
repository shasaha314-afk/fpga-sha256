%% sha256_test.m
% Verification script for sha256.m
% Run after placing sha256.m on your MATLAB path.
%
% All expected values come from NIST FIPS 180-4 test vectors and
% cross-verified with Python hashlib / OpenSSL.

fprintf('=================================================\n');
fprintf('          SHA-256 Verification Tests             \n');
fprintf('=================================================\n\n');

pass = 0;
fail = 0;

% Format: { input_string,  expected_hex_digest }
tests = {
    '',      'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855';
    'abc',   'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad';
    'abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq', ...
             '248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1';
    'hello', '2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824';
    'The quick brown fox jumps over the lazy dog', ...
             'd7a8fbb307d7809469ca9abcb0082e4f8d5651e46d3cdb762d02d0bf37c9e592';
    'The quick brown fox jumps over the lazy dog.', ...
             'ef537f25c895bfa782526529a9b63d97aa631564d5d789c2b765448c8635fb6c';
    'SHA-256 is a cryptographic hash function', ...
             ''; % no known reference -- will print INFO only
};

for i = 1:size(tests, 1)
    inp      = tests{i, 1};
    expected = tests{i, 2};
    got      = sha256(inp);

    if isempty(expected)
        fprintf('[INFO ] Input : "%s"\n', inp);
        fprintf('        Digest: %s\n\n', got);
    elseif strcmpi(got, expected)
        fprintf('[PASS ] "%s"\n        %s\n\n', inp, got);
        pass = pass + 1;
    else
        fprintf('[FAIL ] "%s"\n', inp);
        fprintf('        Got     : %s\n', got);
        fprintf('        Expected: %s\n\n', expected);
        fail = fail + 1;
    end
end

fprintf('-------------------------------------------------\n');
fprintf('Results: %d passed, %d failed out of %d tests\n', ...
        pass, fail, pass + fail);
fprintf('=================================================\n');

%% Interactive usage demo
fprintf('\n--- Interactive Demo ---\n');
samples = {'Himachal Pradesh', '12345', 'MATLAB SHA256', 'SHA2-256 Hardware'};
for k = 1:numel(samples)
    fprintf('sha256("%s")\n  = %s\n\n', samples{k}, sha256(samples{k}));
end