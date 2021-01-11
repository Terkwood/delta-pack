use sled::IVec;
use std::path::PathBuf;
use structopt::StructOpt;
use validator::Validate;

#[derive(StructOpt, Debug, Validate)]
#[structopt(name = "remove-delta")]
struct Opts {
    /// Path to the directory for the embedded DB data
    #[structopt(long, parse(from_os_str))]
    data_dir: PathBuf,

    /// The release to remove
      #[validate(regex = "RE_SEMVER")]
      #[structopt(short, long)]
      release_version: String,
}


fn main() -> sled::Result<()> {
    let opts = Opts::from_args();
    if let Err(e) = opts.validate() {
        eprintln!("Failed to validate arguments: {}", e);
        std::process::exit(1)
    }

    // this directory will be created if it does not exist
    let path = &opts.data_dir;

    let db = sled::open(path)?;


    let version_id_tree: sled::Tree = db.open_tree(b"version->id lookup")?;
    let id = version_id_tree.get(&opts.release_version)?.map(|i|u64::from_be_bytes(i.as_ref()));


    println!("Removing delta with ID: {:#?}", id);

    db.remove(
        id
    )?;

    Ok(())
}
