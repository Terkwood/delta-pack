#[macro_use]
extern crate lazy_static;

use regex::Regex;
use structopt::StructOpt;
use validator::Validate;
lazy_static! {
    static ref RE_HEX: Regex = Regex::new(r"^[0-9a-fA-F]+$").unwrap();
    /// See https://semver.org/#is-there-a-suggested-regular-expression-regex-to-check-a-semver-string
    static ref RE_SEMVER: Regex = Regex::new(r"^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:-((?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*)(?:\.(?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*))*))?(?:\+([0-9a-zA-Z-]+(?:\.[0-9a-zA-Z-]+)*))?$").unwrap();
}
#[derive(StructOpt, Debug, Validate)]
#[structopt(name = "metadata-writer")]
struct Delta {
    #[validate(regex = "RE_SEMVER")]
    #[structopt(short, long)]
    release_version: String,

    /// URL for the diff binary
    #[validate(url)]
    #[structopt(long)]
    diff_url: String,

    /// Hex string checksum for the diff binary
    #[validate(regex = "RE_HEX")]
    #[structopt(long)]
    diff_blake2: String,

    /// Hex string checksum for the expected PCK file
    #[validate(regex = "RE_HEX")]
    #[structopt(short, long)]
    expected_pck_blake2: String,
}

fn main() -> sled::Result<()> {
    let delta = Delta::from_args();
    if let Err(e) = delta.validate() {
        eprintln!("Failed to validate input: {}", e);
        std::process::exit(1)
    }
    println!("{:#?}", delta);

    // this directory will be created if it does not exist
    let path = "/tmp/metadata-tmp";

    // works like std::fs::open
    let db = sled::open(path)?;

    // key and value types can be `Vec<u8>`, `[u8]`, or `str`.
    let key = "delta-metadata";

    // `generate_id`
    let _value = db.generate_id()?.to_be_bytes();

    dbg!(
        //db.insert(key, &value)?, // as in BTreeMap::insert
        db.get(key)?, // as in BTreeMap::get
                      //db.remove(key)?,         // as in BTreeMap::remove
    );

    Ok(())
}
