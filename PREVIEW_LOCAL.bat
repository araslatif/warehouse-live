@echo off
cd /d "%~dp0public"
where py >nul 2>nul && (py -m http.server 8080 & start "" http://127.0.0.1:8080 & exit /b)
where python >nul 2>nul && (python -m http.server 8080 & start "" http://127.0.0.1:8080 & exit /b)
echo Python was not found. You can still deploy the public folder directly to Netlify/Cloudflare Pages/Vercel.
pause
