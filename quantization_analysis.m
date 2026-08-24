clear; clc; close all;


bit_depths          = [4 6 8 10 12 16 20 24 32];      
snr_channel_db       = [0 5 10 15 20 30];            
snr_bit_channel_db   = [-8 -5 -2 0 2 4 6 8 10];       

output_dir      = 'quantization_outputs';
audio_dir       = fullfile(output_dir, 'reconstructed_audio');          
audio_dir_bits  = fullfile(output_dir, 'reconstructed_audio_biterror'); 
plots_dir       = fullfile(output_dir, 'plots');

for d = {output_dir, audio_dir, audio_dir_bits, plots_dir}
    if ~exist(d{1}, 'dir'); mkdir(d{1}); end
end


user_file = 'my_audio.wav';   

if exist(user_file, 'file')
    [x, Fs] = audioread(user_file);
    if size(x, 2) > 1
        x = mean(x, 2);
    end
    fprintf('سیگنال از فایل کاربر بارگذاری شد: %s\n', user_file);
else
    load handel.mat y Fs
    x = y;
    fprintf('فایل صوتی کاربر یافت نشد. از سیگنال نمونه‌ی داخلی MATLAB (handel) استفاده شد.\n');
end

x = x(:);
x = x / max(abs(x));           % نرمال‌سازی به بازه‌ی [-1, +1]

N       = length(x);
x_power = mean(x.^2);

fprintf('طول سیگنال: %d نمونه | Fs = %d Hz | توان متوسط سیگنال = %.5f\n', N, Fs, x_power);
audiowrite(fullfile(output_dir, 'original_signal.wav'), x, Fs);


n_bits  = length(bit_depths);
n_noise = length(snr_channel_db) + 1;

results_MSE  = zeros(n_bits, n_noise);
results_SNR  = zeros(n_bits, n_noise);
results_PSNR = zeros(n_bits, n_noise);

col_labels = cell(1, n_noise);
col_names  = cell(1, n_noise);
col_labels{1} = 'بدون نویز';
col_names{1}  = 'NoNoise';
for k = 1:length(snr_channel_db)
    col_labels{k+1} = sprintf('SNR = %d dB', snr_channel_db(k));
    col_names{k+1}  = sprintf('SNR_%ddB', snr_channel_db(k));
end

for col = 1:n_noise
    if col == 1
        x_in = x;
    else
        snr_val = snr_channel_db(col - 1);
        x_in    = add_awgn(x, snr_val);
        x_in    = max(min(x_in, 1), -1);
    end

    for row = 1:n_bits
        n_bit = bit_depths(row);
        x_rec = uniform_quantize(x_in, n_bit);

        err      = x - x_rec;
        mse_val  = mean(err.^2);
        snr_val  = 10 * log10(x_power / mse_val);
        psnr_val = 10 * log10(1 / mse_val);

        results_MSE(row, col)  = mse_val;
        results_SNR(row, col)  = snr_val;
        results_PSNR(row, col) = psnr_val;

        fname = sprintf('rec_%02dbit_%s.wav', n_bit, col_names{col});
        audiowrite(fullfile(audio_dir, fname), x_rec, Fs);
    end
end

row_names = cellstr(strcat("bit_", string(bit_depths)));

fprintf('\n================= (مدل آنالوگ) جدول MSE =================\n');
disp(array2table(results_MSE, 'RowNames', row_names, 'VariableNames', col_names));
fprintf('\n================= (مدل آنالوگ) جدول SNR خروجی (dB) =================\n');
disp(array2table(results_SNR, 'RowNames', row_names, 'VariableNames', col_names));
fprintf('\n================= (مدل آنالوگ) جدول PSNR (dB) =================\n');
disp(array2table(results_PSNR, 'RowNames', row_names, 'VariableNames', col_names));

writematrix(results_MSE,  fullfile(output_dir, 'MSE_table.csv'));
writematrix(results_SNR,  fullfile(output_dir, 'SNR_table.csv'));
writematrix(results_PSNR, fullfile(output_dir, 'PSNR_table.csv'));

figure('Name', 'Analog channel - combined metrics', 'Position', [80 30 850 1050]);

subplot(3,1,1);
semilogy(bit_depths, results_MSE, '-o', 'LineWidth', 1.5);
xlabel('تعداد بیت کوانتیزاسیون'); ylabel('MSE');
legend(col_labels, 'Location', 'eastoutside'); grid on;
title('MSE بر حسب تعداد بیت');

subplot(3,1,2);
plot(bit_depths, results_SNR, '-o', 'LineWidth', 1.5);
xlabel('تعداد بیت کوانتیزاسیون'); ylabel('SNR خروجی (dB)');
legend(col_labels, 'Location', 'eastoutside'); grid on;
title('SNR خروجی بر حسب تعداد بیت');

subplot(3,1,3);
plot(bit_depths, results_PSNR, '-o', 'LineWidth', 1.5);
xlabel('تعداد بیت کوانتیزاسیون'); ylabel('PSNR (dB)');
legend(col_labels, 'Location', 'eastoutside'); grid on;
title('PSNR بر حسب تعداد بیت');

sgtitle('نتایج مدل کانال آنالوگ (نویز پیوسته قبل از کوانتیزاسیون)');
saveas(gcf, fullfile(output_dir, 'analog_channel_combined.png'));


n_ber_snr = length(snr_bit_channel_db);

results_MSE_bits  = zeros(n_bits, n_ber_snr);
results_SNR_bits  = zeros(n_bits, n_ber_snr);
results_PSNR_bits = zeros(n_bits, n_ber_snr);
ber_values        = zeros(1, n_ber_snr);

col_labels_bits = cell(1, n_ber_snr);
col_names_bits  = cell(1, n_ber_snr);
for k = 1:n_ber_snr
    v = snr_bit_channel_db(k);
    col_labels_bits{k} = sprintf('Eb/N0 = %d dB', v);
    if v < 0
        col_names_bits{k} = sprintf('EbN0_neg%ddB', abs(v));
    else
        col_names_bits{k} = sprintf('EbN0_%ddB', v);
    end
end

for col = 1:n_ber_snr
    snr_val = snr_bit_channel_db(col);

    for row = 1:n_bits
        n_bit = bit_depths(row);
        [x_rec, ber] = bit_error_quantize(x, n_bit, snr_val);

        if row == 1
            ber_values(col) = ber;   % BER فقط به Eb/N0 بستگی دارد، نه تعداد بیت
        end

        err      = x - x_rec;
        mse_val  = mean(err.^2);
        snr_out  = 10 * log10(x_power / mse_val);
        psnr_val = 10 * log10(1 / mse_val);

        results_MSE_bits(row, col)  = mse_val;
        results_SNR_bits(row, col)  = snr_out;
        results_PSNR_bits(row, col) = psnr_val;

        fname = sprintf('recBER_%02dbit_%s.wav', n_bit, col_names_bits{col});
        audiowrite(fullfile(audio_dir_bits, fname), x_rec, Fs);
    end
end

fprintf('\n================= (مدل دیجیتال-BER) جدول MSE =================\n');
disp(array2table(results_MSE_bits, 'RowNames', row_names, 'VariableNames', col_names_bits));
fprintf('\n================= (مدل دیجیتال-BER) جدول SNR خروجی (dB) =================\n');
disp(array2table(results_SNR_bits, 'RowNames', row_names, 'VariableNames', col_names_bits));
fprintf('\n================= (مدل دیجیتال-BER) جدول PSNR (dB) =================\n');
disp(array2table(results_PSNR_bits, 'RowNames', row_names, 'VariableNames', col_names_bits));

BER_table = table(snr_bit_channel_db', ber_values', 'VariableNames', {'EbN0_dB', 'BER'});
fprintf('\n================= جدول BER بر حسب Eb-N0 =================\n');
disp(BER_table);

writematrix(results_MSE_bits,  fullfile(output_dir, 'MSE_table_biterror.csv'));
writematrix(results_SNR_bits,  fullfile(output_dir, 'SNR_table_biterror.csv'));
writematrix(results_PSNR_bits, fullfile(output_dir, 'PSNR_table_biterror.csv'));
writetable(BER_table, fullfile(output_dir, 'BER_values.csv'));

figure('Name', 'Digital channel - combined metrics', 'Position', [80 30 1050 900]);

subplot(2,2,1);
semilogy(bit_depths, results_MSE_bits, '-o', 'LineWidth', 1.2);
xlabel('تعداد بیت'); ylabel('MSE');
legend(col_labels_bits, 'Location', 'eastoutside', 'FontSize', 7); grid on;
title('MSE بر حسب تعداد بیت');

subplot(2,2,2);
plot(bit_depths, results_SNR_bits, '-o', 'LineWidth', 1.2);
xlabel('تعداد بیت'); ylabel('SNR خروجی (dB)');
legend(col_labels_bits, 'Location', 'eastoutside', 'FontSize', 7); grid on;
title('SNR خروجی بر حسب تعداد بیت');

subplot(2,2,3);
plot(bit_depths, results_PSNR_bits, '-o', 'LineWidth', 1.2);
xlabel('تعداد بیت'); ylabel('PSNR (dB)');
legend(col_labels_bits, 'Location', 'eastoutside', 'FontSize', 7); grid on;
title('PSNR بر حسب تعداد بیت');

subplot(2,2,4);
semilogy(snr_bit_channel_db, ber_values, '-o', 'LineWidth', 1.5);
xlabel('Eb/N0 (dB)'); ylabel('نرخ خطای بیت (BER)'); grid on;
title('منحنی BER (مدل BPSK روی AWGN)');

sgtitle('نتایج مدل کانال دیجیتال (خطای بیت بعد از کوانتیزاسیون)');
saveas(gcf, fullfile(plots_dir, 'digital_channel_combined.png'));


seg_start = max(1, round(N * 0.3));
seg_len   = min(500, N - seg_start);
seg_idx   = seg_start : (seg_start + seg_len - 1);
t_seg     = (0:seg_len-1) / Fs;

rec_matrix_nonoise = zeros(seg_len, n_bits);
for k = 1:n_bits
    x_rec_full = uniform_quantize(x, bit_depths(k));
    rec_matrix_nonoise(:, k) = x_rec_full(seg_idx);
end
plot_bitdepth_stack(t_seg, x(seg_idx), rec_matrix_nonoise, bit_depths, ...
    'بازسازی سیگنال در بیت‌های مختلف - بدون نویز کانال', ...
    fullfile(plots_dir, 'stack_nonoise_allbits.png'));

snr_demo     = 10;   
x_noisy_demo = add_awgn(x, snr_demo);
x_noisy_demo = max(min(x_noisy_demo, 1), -1);

rec_matrix_analog = zeros(seg_len, n_bits);
for k = 1:n_bits
    x_rec_full = uniform_quantize(x_noisy_demo, bit_depths(k));
    rec_matrix_analog(:, k) = x_rec_full(seg_idx);
end
plot_bitdepth_stack(t_seg, x(seg_idx), rec_matrix_analog, bit_depths, ...
    sprintf('بازسازی سیگنال در بیت‌های مختلف - کانال آنالوگ (SNR = %d dB)', snr_demo), ...
    fullfile(plots_dir, 'stack_analog_snr10_allbits.png'));


ebn0_demo = -5;   

rec_matrix_digital = zeros(seg_len, n_bits);
for k = 1:n_bits
    [x_rec_full, ~] = bit_error_quantize(x, bit_depths(k), ebn0_demo);
    rec_matrix_digital(:, k) = x_rec_full(seg_idx);
end
plot_bitdepth_stack(t_seg, x(seg_idx), rec_matrix_digital, bit_depths, ...
    sprintf('بازسازی سیگنال در بیت‌های مختلف - کانال دیجیتال (Eb/N0 = %d dB)', ebn0_demo), ...
    fullfile(plots_dir, 'stack_digital_ebn0neg5_allbits.png'));


x_rec_spec_demo = uniform_quantize(x_noisy_demo, 6);
plot_spectrum_comparison(x, x_rec_spec_demo, Fs, ...
    sprintf('طیف: ۶ بیت، SNR کانال آنالوگ = %d dB', snr_demo), ...
    fullfile(plots_dir, 'spectrum_6bit_snr10.png'));

fprintf('\nنمودارهای چیده‌شده (سیگنال اصلی + بازسازی همه‌ی بیت‌ها) در پوشه‌ی "%s" ذخیره شدند.\n', plots_dir);


mu = 255;   
x_strong = x;          
x_weak   = x * 0.1;    

power_strong = mean(x_strong.^2);
power_weak   = mean(x_weak.^2);

SNR_uniform_strong   = zeros(1, n_bits);
SNR_uniform_weak     = zeros(1, n_bits);
SNR_companded_strong = zeros(1, n_bits);
SNR_companded_weak   = zeros(1, n_bits);

for k = 1:n_bits
    nb = bit_depths(k);

    rec = uniform_quantize(x_strong, nb);
    SNR_uniform_strong(k) = 10*log10(power_strong / mean((x_strong - rec).^2));

    rec = uniform_quantize(x_weak, nb);
    SNR_uniform_weak(k) = 10*log10(power_weak / mean((x_weak - rec).^2));

    rec = companded_quantize(x_strong, nb, mu);
    SNR_companded_strong(k) = 10*log10(power_strong / mean((x_strong - rec).^2));

    rec = companded_quantize(x_weak, nb, mu);
    SNR_companded_weak(k) = 10*log10(power_weak / mean((x_weak - rec).^2));
end

fprintf('\n========== مقایسه‌ی SQNR: یکنواخت در مقابل غیریکنواخت (μ-law) ==========\n');
comp_table = table(bit_depths', SNR_uniform_strong', SNR_uniform_weak', ...
    SNR_companded_strong', SNR_companded_weak', ...
    'VariableNames', {'Bits', 'Uniform_Strong', 'Uniform_Weak', 'Companded_Strong', 'Companded_Weak'});
disp(comp_table);
writetable(comp_table, fullfile(output_dir, 'companding_comparison.csv'));

figure('Name', 'Companding comparison', 'Position', [80 30 1100 500]);

subplot(1,2,1);
plot(bit_depths, SNR_uniform_strong, '-o', bit_depths, SNR_companded_strong, '-s', 'LineWidth', 1.5);
xlabel('تعداد بیت'); ylabel('SNR خروجی (dB)');
legend('یکنواخت', 'غیریکنواخت (μ-law)', 'Location', 'best'); grid on;
title('سیگنال قوی (دامنه‌ی کامل)');

subplot(1,2,2);
plot(bit_depths, SNR_uniform_weak, '-o', bit_depths, SNR_companded_weak, '-s', 'LineWidth', 1.5);
xlabel('تعداد بیت'); ylabel('SNR خروجی (dB)');
legend('یکنواخت', 'غیریکنواخت (μ-law)', 'Location', 'best'); grid on;
title('سیگنال ضعیف (۱۰٪ دامنه)');

sgtitle('مقایسه‌ی SQNR: کوانتایزر یکنواخت در مقابل غیریکنواخت (μ-law، بدون نویز کانال)');
saveas(gcf, fullfile(plots_dir, 'companding_comparison.png'));

fprintf('نمودار و جدول مقایسه‌ی کوانتیزاسیون غیریکنواخت ذخیره شد.\n');


save(fullfile(output_dir, 'results.mat'), ...
    'results_MSE', 'results_SNR', 'results_PSNR', ...
    'results_MSE_bits', 'results_SNR_bits', 'results_PSNR_bits', 'ber_values', ...
    'SNR_uniform_strong', 'SNR_uniform_weak', 'SNR_companded_strong', 'SNR_companded_weak', ...
    'bit_depths', 'snr_channel_db', 'snr_bit_channel_db', ...
    'col_labels', 'col_labels_bits', 'x_power');

fprintf('\nپردازش کامل شد. تمام جدول‌ها، فایل‌های صوتی و نمودارها در پوشه‌ی "%s" ذخیره شدند.\n', output_dir);




function x_q = uniform_quantize(x, n_bits)
  
    q    = 2 ^ n_bits;
    step = 2 / q;

    x_clipped = max(min(x, 1 - eps), -1);
    idx = floor((x_clipped + 1) / step);
    idx = min(idx, q - 1);

    x_q = -1 + step/2 + idx * step;
end


function y = add_awgn(x, snr_db)
  
    sig_power   = mean(x.^2);
    snr_linear  = 10 ^ (snr_db / 10);
    noise_power = sig_power / snr_linear;
    noise       = sqrt(noise_power) * randn(size(x));
    y = x + noise;
end


function [x_rec, ber] = bit_error_quantize(x, n_bits, snr_db)
   
    q    = 2 ^ n_bits;
    step = 2 / q;

    x_clipped = max(min(x, 1 - eps), -1);
    idx = floor((x_clipped + 1) / step);
    idx = min(idx, q - 1);          

    EbN0_linear = 10 ^ (snr_db / 10);
    ber = 0.5 * erfc(sqrt(EbN0_linear));

    idx_rx = idx;
    for b = 1:n_bits
        bit_val   = bitget(idx, b);
        flip_mask = rand(size(idx)) < ber;
        idx_rx    = bitset(idx_rx, b, xor(bit_val, flip_mask));
    end

    x_rec = -1 + step/2 + idx_rx * step;
end


function y = mu_law_compress(x, mu)
   
    y = sign(x) .* log(1 + mu * abs(x)) / log(1 + mu);
end


function x = mu_law_expand(y, mu)
   
    x = sign(y) .* ((1 + mu).^abs(y) - 1) / mu;
end


function x_q = companded_quantize(x, n_bits, mu)
    
    y   = mu_law_compress(x, mu);
    y_q = uniform_quantize(y, n_bits);
    x_q = mu_law_expand(y_q, mu);
end


function plot_waveform_and_error(t, x_orig, x_rec, fig_title, save_path)
   
    figure('Name', fig_title, 'Position', [100 100 900 500]);

    subplot(2,1,1);
    plot(t, x_orig, 'b-', 'LineWidth', 1.2); hold on;
    stairs(t, x_rec, 'r-', 'LineWidth', 1.0);
    legend('سیگنال اصلی', 'سیگنال بازسازی‌شده', 'Location', 'best');
    xlabel('زمان (ثانیه)'); ylabel('دامنه');
    title(fig_title);
    grid on;

    subplot(2,1,2);
    plot(t, x_orig - x_rec, 'k-', 'LineWidth', 1.0);
    xlabel('زمان (ثانیه)'); ylabel('خطا');
    title('سیگنال خطا (اصلی - بازسازی‌شده)');
    grid on;

    saveas(gcf, save_path);
end


function plot_bitdepth_stack(t, x_orig, rec_matrix, bit_depths, fig_title, save_path)
   
    n_bit_count = length(bit_depths);
    total_rows  = n_bit_count + 1;

    ylims = [min([x_orig(:); rec_matrix(:)]) - 0.05, max([x_orig(:); rec_matrix(:)]) + 0.05];

    figure('Name', fig_title, 'Position', [80 30 900 115 * total_rows]);

    subplot(total_rows, 1, 1);
    plot(t, x_orig, 'b-', 'LineWidth', 1.2);
    ylim(ylims); grid on;
    title('سیگنال اصلی', 'FontWeight', 'bold');
    set(gca, 'XTickLabel', []);

    for k = 1:n_bit_count
        subplot(total_rows, 1, k + 1);
        stairs(t, rec_matrix(:, k), 'r-', 'LineWidth', 1.0);
        ylim(ylims); grid on;
        title(sprintf('بازسازی با %d بیت', bit_depths(k)));
        if k < n_bit_count
            set(gca, 'XTickLabel', []);
        else
            xlabel('زمان (ثانیه)');
        end
    end

    sgtitle(fig_title);
    saveas(gcf, save_path);
end


function plot_spectrum_comparison(x_orig, x_rec, Fs, fig_title, save_path)
   
    Nlen = length(x_orig);
    f    = (0:Nlen-1) * (Fs/Nlen);
    half = 1:floor(Nlen/2);

    X_orig = abs(fft(x_orig));
    X_rec  = abs(fft(x_rec));

    figure('Name', fig_title, 'Position', [100 100 900 400]);
    plot(f(half), 20*log10(X_orig(half)+eps), 'b-', 'LineWidth', 1.0); hold on;
    plot(f(half), 20*log10(X_rec(half)+eps), 'r-', 'LineWidth', 1.0);
    xlabel('فرکانس (Hz)'); ylabel('دامنه طیف (dB)');
    legend('سیگنال اصلی', 'سیگنال بازسازی‌شده', 'Location', 'best');
    title(fig_title);
    grid on;
    saveas(gcf, save_path);
end