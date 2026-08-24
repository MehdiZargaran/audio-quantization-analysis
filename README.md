# audio-quantization-analysis
# Audio Quantization & Digital Transmission Analysis (MATLAB)

تحلیل جامع اثر کوانتیزاسیون بر کیفیت سیگنال صوتی، شامل شبیه‌سازی کانال آنالوگ (AWGN) و کانال دیجیتال (خطای بیت پس از مدولاسیون BPSK).

## قابلیت‌ها
- کوانتیزاسیون یکنواخت (Uniform) با بیت‌عمق‌های مختلف (4 تا 32 بیت)
- کوانتیزاسیون غیریکنواخت با فشرده‌سازی μ-law (Companding) و مقایسه با حالت یکنواخت
- مدل‌سازی کانال آنالوگ نویزی (AWGN) قبل از کوانتیزاسیون
- مدل‌سازی کانال دیجیتال با خطای بیت بر اساس BER نظری BPSK (تابع erfc)
- محاسبه معیارهای MSE، SNR خروجی، PSNR برای همه سناریوها
- رسم منحنی BER بر حسب Eb/N0
- مقایسه طیف فرکانسی سیگنال اصلی و بازسازی‌شده (FFT)
- خروجی فایل‌های صوتی بازسازی‌شده، جداول CSV و نمودارهای PNG

## نحوه اجرا
1. MATLAB را باز کنید
2. (اختیاری) یک فایل صوتی با نام `my_audio.wav` در کنار اسکریپت قرار دهید؛ در غیر این صورت از سیگنال نمونه داخلی MATLAB استفاده می‌شود
3. فایل `quantization_analysis.m` را اجرا کنید
4. خروجی‌ها در پوشه `quantization_outputs/` ذخیره می‌شوند (فایل‌های صوتی، جداول CSV، نمودارها)

## ساختار خروجی
```
quantization_outputs/
├── reconstructed_audio/          # سیگنال بازسازی‌شده - کانال آنالوگ
├── reconstructed_audio_biterror/ # سیگنال بازسازی‌شده - کانال دیجیتال
├── plots/                        # نمودارهای مقایسه‌ای
├── MSE_table.csv, SNR_table.csv, PSNR_table.csv
├── BER_values.csv
├── companding_comparison.csv
└── results.mat
```

## معیارهای ارزیابی
- **MSE** (Mean Squared Error)
- **SNR** خروجی (dB)
- **PSNR** (dB)
- **BER** (بر اساس مدل تئوری BPSK روی AWGN)

## ابزارها
MATLAB 
