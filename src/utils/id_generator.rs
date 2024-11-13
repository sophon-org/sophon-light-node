use avail_rust::{
    sp_core::crypto::{self, Ss58Codec},
    subxt_signer::SecretUri,
    Keypair,
};
use std::env;
use std::str::FromStr;

fn main() {
    // get secret_uri (mnemonic) from command-line arguments
    let args: Vec<String> = env::args().collect();
    if args.len() != 2 {
        eprintln!("Usage: {} <secret_uri>", args[0]);
        std::process::exit(1);
    }
    let secret_uri_str = &args[1];

    // parse secret_uri
    let secret_uri = SecretUri::from_str(secret_uri_str).expect("Invalid secret_uri");

    // generate Keypair
    let avail_key_pair = Keypair::from_uri(&secret_uri).expect("Failed to generate Keypair");

    let avail_address = avail_key_pair.public_key().to_account_id();
    let avail_address = crypto::AccountId32::from(avail_address.0).to_ss58check();
    // let avail_public_key = hex::encode(avail_key_pair.public_key());

    println!("{}", avail_address);
}
