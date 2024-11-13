use std::fs;
use std::process::Command;

const MAIN_SCRIPT: &str = include_str!("../light-node/main.sh");
const SOPHONUP_SCRIPT: &str = include_str!("../light-node/sophonup.sh");
const REGISTER_SCRIPT: &str = include_str!("../light-node/register_lc.sh");

fn main() {
    // check if --version exists
    if std::env::args().any(|arg| arg == "--version" || arg == "-v") {
        println!("v{}", env!("CARGO_PKG_VERSION"));
        std::process::exit(0);
    }

    // write scripts to disk
    fs::write("main.sh", MAIN_SCRIPT).expect("Failed to write main.sh");
    fs::write("sophonup.sh", SOPHONUP_SCRIPT).expect("Failed to write sophonup.sh");
    fs::write("register_lc.sh", REGISTER_SCRIPT).expect("Failed to write register_lc.sh");

    // make them executable
    Command::new("chmod")
        .args(&["+x", "main.sh", "sophonup.sh", "register_lc.sh"])
        .status()
        .expect("Failed to make scripts executable");

    // get command line arguments
    let args: Vec<String> = std::env::args().collect();

    // execute main.sh with all passed arguments
    let status = Command::new("./main.sh")
        .args(&args[1..]) // skip the first arg which is the program name
        .status()
        .expect("failed to execute main.sh");

    std::process::exit(status.code().unwrap_or(1));
}
