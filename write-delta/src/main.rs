#[macro_use]
extern crate lazy_static;
#[macro_use]
extern crate serde_derive;

use std::path::PathBuf;

use regex::Regex;
use sled::IVec;
use structopt::StructOpt;
use validator::Validate;

lazy_static! {
    static ref RE_HEX: Regex = Regex::new(r"^[0-9a-fA-F]+$").unwrap();
    /// See https://semver.org/#is-there-a-suggested-regular-expression-regex-to-check-a-semver-string
    static ref RE_SEMVER: Regex = Regex::new(r"^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:-((?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*)(?:\.(?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*))*))?(?:\+([0-9a-zA-Z-]+(?:\.[0-9a-zA-Z-]+)*))?$").unwrap();
}
#[derive(StructOpt, Debug, Validate)]
#[structopt(name = "write-delta")]
struct Opts {
    /// Path to the directory for the embedded DB data
    #[structopt(long, parse(from_os_str))]
    data_dir: PathBuf,

    /// The current version of the PCK file
    #[validate(regex = "RE_SEMVER")]
    #[structopt(short, long)]
    release_version: String,

    /// The previous version of the PCK file
    /// to which this diff should be applied
    #[validate(regex = "RE_SEMVER")]
    #[structopt(short, long)]
    previous_version: String,

    /// URL for the diff binary
    #[validate(url)]
    #[structopt(long)]
    diff_url: String,

    /// BLAKE2b checksum (hex string) for the diff binary
    #[validate(regex = "RE_HEX")]
    #[structopt(long)]
    diff_b2bsum: String,

    /// BLAKE2b checksum (hex string) for the PCK file generated by applying the diff
    #[validate(regex = "RE_HEX")]
    #[structopt(short, long)]
    expected_pck_b2bsum: String,
}

#[derive(Serialize, Deserialize)]
pub struct Delta {
    pub id: u64,
    pub release_version: String,
    pub previous_version: String,
    pub diff_url: String,
    pub diff_b2bsum: String,
    pub expected_pck_b2bsum: String,
}

impl From<(u64, Opts)> for Delta {
    fn from(
        (
            id,
            Opts {
                diff_url,
                diff_b2bsum,
                expected_pck_b2bsum,
                release_version,
                previous_version,
                data_dir: _,
            },
        ): (u64, Opts),
    ) -> Self {
        Delta {
            id,
            diff_b2bsum,
            diff_url,
            expected_pck_b2bsum,
            release_version,
            previous_version,
        }
    }
}

fn main() -> sled::Result<()> {
    let opts = Opts::from_args();
    if let Err(e) = opts.validate() {
        eprintln!("Failed to validate input: {}", e);
        std::process::exit(1)
    }
    println!("Writing delta: {:#?}", opts);

    // this directory will be created if it does not exist
    let path = "/tmp/metadata-tmp";

    let db = sled::open(path)?;

    let id = db.generate_id()?;

    let key = format!("deltas/{}", id);

    let value = bincode::serialize(&Delta::from((id, opts))).expect("serialize");
    db.insert(key, &IVec::from(value))?;
    Ok(())
}
