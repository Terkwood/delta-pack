use anyhow::{Context, Result};
use blake2::{Blake2b, Digest};
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
        hex::decode(expected_checksum.to_string())
            .and_then(|expected| {
                let f = file_path.to_string();
                Ok(fs::File::open(&f)
                    .and_then(|mut file| {
                        let computed = compute_checksum(&mut file);
                        Ok(computed.map(|actual| actual == expected).unwrap_or(false))
                    })
                    .unwrap_or(false))
            })
            .unwrap_or(false)
    }

    /// Apply a diff to create a new PCK file. See https://github.com/divvun/bidiff/blob/1e6571e8f36bba3292b33a4b7dfe4ce93a3abd1e/crates/bic/src/main.rs#L257
    #[export]
    fn apply_diff(
        &self,
        _owner: &Label,
        input_pck_path: GodotString,
        diff_bin_path: GodotString,
        output_pck_path: GodotString,
    ) -> bool {
        godot_print!("output path {}", output_pck_path.to_string());
        if let Err(e) = patch(
            &PathBuf::from_str(&input_pck_path.to_string()).expect("path to input PCK"),
            &PathBuf::from_str(&diff_bin_path.to_string()).expect("path to diff bin"),
            &PathBuf::from_str(&output_pck_path.to_string()).expect("path to output PCK"),
        ) {
            godot_print!("Error applying patch: {:#?}", e);
            false
        } else {
            true
        }
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
fn compute_checksum<R: Read>(reader: &mut R) -> Result<Vec<u8>> {
    let mut hasher = Blake2b::new();
    let mut buffer = [0u8; BUFFER_SIZE];
    loop {
        let n = reader.read(&mut buffer)?;
        hasher.update(&buffer[..n]);
        if n == 0 || n < BUFFER_SIZE {
            break;
        }
    }
    Ok(hasher.finalize().to_vec())
}

fn init(handle: InitHandle) {
    handle.add_class::<IncrementalPatch>();
}

godot_init!(init);
