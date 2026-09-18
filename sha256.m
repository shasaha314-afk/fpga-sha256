function digest = sha256(input_str)
% SHA256  Compute the SHA-2/256 hash of a string.
%
%   digest = sha256(input_str)
%
%   INPUT:
%       input_str  - character array or string (ASCII)
%
%   OUTPUT:
%       digest     - 64-character lowercase hex string (256-bit hash)
%
%   Example:
%       sha256('')
%         -> e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855
%       sha256('abc')
%         -> ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad
%       sha256('hello')
%         -> 2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824
%
%   Implements NIST FIPS 180-4 SHA-256, mirroring the hardware round
%   function in Fig. 7:
%       Sigma0 / Sigma1  : big-sigma rotation functions on a and e
%       sigma0 / sigma1  : small-sigma functions for the message schedule
%       Maj, Ch          : majority and choice functions
%       add32 (= plus)   : 32-bit addition modulo 2^32 (carry ignored)
%
%   KEY FIX: MATLAB's xor() is LOGICAL XOR (returns 0 or 1).
%   All bitwise XOR operations use bitxor() instead.

    % ------------------------------------------------------------------ %
    %  Initial hash values H0-H7 (FIPS 180-4 section 5.3.3)             %
    % ------------------------------------------------------------------ %
    H = uint32([
        0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a, ...
        0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19
    ]);

    % ------------------------------------------------------------------ %
    %  Round constants Kt (FIPS 180-4 section 4.2.2)                     %
    % ------------------------------------------------------------------ %
    K = uint32([
        0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, ...
        0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5, ...
        0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, ...
        0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174, ...
        0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, ...
        0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da, ...
        0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, ...
        0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967, ...
        0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, ...
        0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85, ...
        0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, ...
        0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070, ...
        0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, ...
        0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3, ...
        0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, ...
        0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2
    ]);

    % ------------------------------------------------------------------ %
    %  Pre-processing: message padding (FIPS 180-4 section 5.1.1)         %
    % ------------------------------------------------------------------ %
    msg    = uint8(input_str);
    L      = numel(msg);
    L_bits = uint64(L) * 8;

    % Append 0x80 byte
    msg = [msg, uint8(0x80)];

    % Pad with zeros until length is 56 mod 64
    while mod(numel(msg), 64) ~= 56
        msg = [msg, uint8(0x00)];
    end

    % Append 64-bit big-endian original bit-length
    len_bytes = uint8(zeros(1, 8));
    for i = 1:8
        shift_amt = 8 * (8 - i);   % i=1 -> shift 56 (MSB), i=8 -> shift 0 (LSB)
        len_bytes(i) = uint8(bitand(bitshift(L_bits, -shift_amt), uint64(0xFF)));
    end
    msg = [msg, len_bytes];

    % ------------------------------------------------------------------ %
    %  Process each 512-bit (64-byte) block                               %
    % ------------------------------------------------------------------ %
    num_blocks = numel(msg) / 64;

    for blk = 1:num_blocks
        block = msg((blk-1)*64 + 1 : blk*64);

        % -------------------------------------------------------------- %
        %  Message Schedule: 64 words Wt                                  %
        % -------------------------------------------------------------- %
        W = uint32(zeros(1, 64));

        % First 16 words from block bytes (big-endian)
        for t = 1:16
            idx  = (t-1)*4 + 1;
            W(t) = bitor(bitor(bitor( ...
                bitshift(uint32(block(idx)),   24), ...
                bitshift(uint32(block(idx+1)), 16)), ...
                bitshift(uint32(block(idx+2)),  8)), ...
                         uint32(block(idx+3)));
        end

        % Words 17-64 via small-sigma functions
        %   sigma1(x) = ROTR17(x) XOR ROTR19(x) XOR SHR10(x)
        %   sigma0(x) = ROTR7(x)  XOR ROTR18(x) XOR SHR3(x)
        for t = 17:64
            sig1 = bitxor(bitxor(rotr32(W(t-2), 17), rotr32(W(t-2), 19)), ...
                          bitshift(W(t-2), -10));
            sig0 = bitxor(bitxor(rotr32(W(t-15), 7), rotr32(W(t-15), 18)), ...
                          bitshift(W(t-15), -3));
            W(t) = add32(add32(add32(sig1, W(t-7)), sig0), W(t-16));
        end

        % -------------------------------------------------------------- %
        %  Initialize working variables a-h from H0-H7                   %
        % -------------------------------------------------------------- %
        a = H(1); b = H(2); c = H(3); d = H(4);
        e = H(5); f = H(6); g = H(7); h = H(8);

        % -------------------------------------------------------------- %
        %  64 rounds of the round function (matches Fig. 7)               %
        % -------------------------------------------------------------- %
        for t = 1:64
            % Sigma1(e) = ROTR6(e) XOR ROTR11(e) XOR ROTR25(e)
            S1  = bitxor(bitxor(rotr32(e,  6), rotr32(e, 11)), rotr32(e, 25));

            % Ch(e,f,g) = (e AND f) XOR (NOT_e AND g)
            ch  = bitxor(bitand(e, f), bitand(bitcmp(e, 'uint32'), g));

            % T1 = h + Sigma1(e) + Ch(e,f,g) + Kt + Wt
            T1  = add32(add32(add32(add32(h, S1), ch), K(t)), W(t));

            % Sigma0(a) = ROTR2(a) XOR ROTR13(a) XOR ROTR22(a)
            S0  = bitxor(bitxor(rotr32(a,  2), rotr32(a, 13)), rotr32(a, 22));

            % Maj(a,b,c) = (a AND b) XOR (a AND c) XOR (b AND c)
            maj = bitxor(bitxor(bitand(a, b), bitand(a, c)), bitand(b, c));

            % T2 = Sigma0(a) + Maj(a,b,c)
            T2  = add32(S0, maj);

            % Update working variables (a' through h' in Fig. 7)
            h = g;
            g = f;
            f = e;
            e = add32(d, T1);   % new e
            d = c;
            c = b;
            b = a;
            a = add32(T1, T2);  % new a
        end

        % -------------------------------------------------------------- %
        %  H0'-H7' = H0-H7 + a-h  (right-hand adders in Fig. 7)         %
        % -------------------------------------------------------------- %
        H(1) = add32(H(1), a);
        H(2) = add32(H(2), b);
        H(3) = add32(H(3), c);
        H(4) = add32(H(4), d);
        H(5) = add32(H(5), e);
        H(6) = add32(H(6), f);
        H(7) = add32(H(7), g);
        H(8) = add32(H(8), h);
    end

    % ------------------------------------------------------------------ %
    %  Final 256-bit digest as 64-character hex string                    %
    % ------------------------------------------------------------------ %
    digest = sprintf('%08x%08x%08x%08x%08x%08x%08x%08x', ...
        H(1), H(2), H(3), H(4), H(5), H(6), H(7), H(8));
end


% ======================================================================= %
%  Helper: 32-bit circular right-rotation                                  %
%  ROTR_n(x) = (x >>> n) | (x <<< (32-n))                                %
% ======================================================================= %
function y = rotr32(x, n)
    y = bitor(bitshift(x, -n), bitshift(x, 32 - n));
end


% ======================================================================= %
%  Helper: 32-bit modular addition  (the "plus" box in Fig. 7)            %
%  Cast to uint64 to safely add, then truncate to 32 bits.                %
% ======================================================================= %
function s = add32(a, b)
    s = uint32(mod(uint64(a) + uint64(b), uint64(2)^32));
end