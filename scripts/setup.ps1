# Install Python
$pythonUrl = "https://www.python.org/ftp/python/3.9.7/python-3.9.7-amd64.exe"
$pythonInstaller = "$env:TEMP\python-installer.exe"
Invoke-WebRequest -Uri $pythonUrl -OutFile $pythonInstaller
Start-Process -FilePath $pythonInstaller -Args "/quiet InstallAllUsers=1 PrependPath=1" -Wait

# Install required Python packages
pip install pyautogui
pip install pywinauto
pip install opencv-python
pip install pillow

# Run the automation script
python /automation/automation.py

