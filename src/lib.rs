use anyhow::{Context, Result};
use gdnative::api::*;
use gdnative::prelude::*;
use std::fs;
use std::io::Read;
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
        expected_checksum: GodotString,
    ) -> bool {
        make_hash(expected_checksum)
            .and_then(|expected| {
                fs::File::open(&file_path.to_string())
                    .map(|mut file| {
                        if let Ok(actual_checksum) = compute_checksum(&mut file) {
                            actual_checksum == expected
                        } else {
                            godot_print!("could not compute checksum against file");
                            false
                        }
                    })
                    .map_err(|e| e.into())
            })
            .unwrap_or(false)
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

const BUFFER_SIZE: usize = 1024;
fn compute_checksum<R: Read>(reader: &mut R) -> Result<blake3::Hash> {
    let mut hasher = blake3::Hasher::new();
    let mut buffer = [0u8; BUFFER_SIZE];
    loop {
        let n = reader.read(&mut buffer)?;
        hasher.update(&buffer[..n]);
        if n == 0 || n < BUFFER_SIZE {
            break;
        }
    }
    Ok(hasher.finalize())
}

fn make_hash(gs: GodotString) -> Result<blake3::Hash> {
    use std::convert::TryInto;
    let hash_bytes = hex::decode(gs.to_string())?;
    todo!()
}

fn init(handle: InitHandle) {
    handle.add_class::<IncrementalPatch>();
}

godot_init!(init);
