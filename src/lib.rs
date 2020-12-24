use anyhow::{Context, Result};
use gdnative::api::*;
use gdnative::prelude::*;
use std::{
    fs::File,
    io::{self, BufReader, BufWriter},
    path::PathBuf,
    str::FromStr,
    time::Instant,
};

#[derive(gdnative::NativeClass)]
#[inherit(Label)]
struct IncrementalPatch;

const OLD_PCK: &str = "test-0.0.0.pck";
const OUT_PCK: &str = "test-0.0.0-DELTA.pck";

#[gdnative::methods]
impl IncrementalPatch {
    fn new(_owner: &Label) -> Self {
        IncrementalPatch
    }

    /// Verifies that a file hashes to the expected value
    #[export]
    fn verify_checksum(
        &self,
        _owner: &Label,
        file_path: GodotString,
        blake3_hash: GodotString,
    ) -> bool {
        todo!("compute blake3 from the file");
        todo!("compare to provided blake3 hash")
    }

    /// Apply a patch, as in https://github.com/divvun/bidiff/blob/1e6571e8f36bba3292b33a4b7dfe4ce93a3abd1e/crates/bic/src/main.rs#L257
    #[export]
    fn test_patch(&self, _owner: &Label, diff_bin_path: GodotString) {
        patch(
            &PathBuf::from_str(OLD_PCK).expect("path to old PCK"),
            &PathBuf::from_str(&diff_bin_path.to_string()).expect("path to diff bin"),
            &PathBuf::from_str(OUT_PCK).expect("path to output PCK"),
        )
        .expect("boom")
    }

    #[export]
    fn _ready(&mut self, _owner: &Label) {
        godot_print!("Delta Pack ready");
    }
}

fn patch(older: &PathBuf, patch: &PathBuf, output: &PathBuf) -> Result<()> {
    let start = Instant::now();

    let compatch_r = BufReader::new(File::open(patch).context("open patch file")?);
    let (patch_r, patch_w) = pipe::pipe();
    use comde::Decompressor;
    let zstd_decompress = comde::zstd::ZstdDecompressor::new();

    std::thread::spawn(move || {
        zstd_decompress
            .copy(compatch_r, patch_w)
            .context("decompress")
            .unwrap();
    });

    let older_r = File::open(older)?;
    let mut fresh_r = bipatch::Reader::new(patch_r, older_r).context("read patch")?;
    let mut output_w = BufWriter::new(File::create(output).context("create patch file")?);
    io::copy(&mut fresh_r, &mut output_w).context("write output file")?;

    godot_print!("Patch applied in {:?}", start.elapsed());

    Ok(())
}

fn init(handle: InitHandle) {
    handle.add_class::<IncrementalPatch>();
}

godot_init!(init);
