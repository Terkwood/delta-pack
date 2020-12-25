#[macro_use]
extern crate lazy_static;

use regex::Regex;
use structopt::StructOpt;
use validator::Validate;
lazy_static! {
    static ref RE_HEX: Regex = Regex::new(r"[0-9a-fA-F]+$").unwrap();
}
#[derive(StructOpt, Debug, Validate)]
#[structopt(name = "metadata-writer")]
struct Delta {
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
