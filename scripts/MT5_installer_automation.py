import time
from pywinauto.application import Application
from pywinauto import timings
import ctypes, sys

def is_admin():
    try:
        return ctypes.windll.shell32.IsUserAnAdmin()
    except:
        return False

if not is_admin():
    ctypes.windll.shell32.ShellExecuteW(None, "runas", sys.executable, " ".join(sys.argv), None, 1)
    sys.exit(0)
    
def wait_for_finish_button(main_dlg, timeout=900):
    """Wait for Finish button to appear and be clickable"""
    start_time = time.time()
    while time.time() - start_time < timeout:
        try:
            # Try different methods to find the Finish button
            finish_button = main_dlg.child_window(title="Finish", control_type="Button")
            if finish_button.is_visible() and finish_button.is_enabled():
                return finish_button
        except:
            pass
        time.sleep(5)  # Check every 5 seconds
    raise TimeoutError("Finish button not found within timeout period")
    
def install_metatrader():
    try:
        timings.Timings.slow()
        print("Step 1: Starting installer...")
        
        app = Application(backend="win32").start("mt5setup.exe", timeout=30)
        print("Step 2: Application started")
        
        app.wait_cpu_usage_lower(threshold=5, timeout=10)
        main_dlg = app.window(title_re=".*Meta.*", visible_only=True, enabled_only=True)
        main_dlg.wait('visible ready enabled', timeout=15)
        print("Step 3: Main window found")
        
        time.sleep(2)
        print("Step 4: Clicking Next...")
        
        main_dlg.Next.click_input()
        main_dlg.Next.wait("ready", timeout=10).click()
        print("Step 5: Installation in progress...")
        
        # Wait for installation to complete and find Finish button
        print("Waiting for installation to complete...")
        try:
            finish_button = wait_for_finish_button(main_dlg)
            print("Finish button found, clicking...")
            finish_button.click_input()
            print("Step 9: Installation completed")
        except TimeoutError as te:
            print(f"Timeout waiting for installation: {str(te)}")
            return
            
        # Verify installation completed
        time.sleep(5)  # Wait for any final operations
        print("Installation completed successfully")
        
    except Exception as e:
        print(f"Installation failed: {str(e)}")

if __name__ == "__main__":
    install_metatrader()
