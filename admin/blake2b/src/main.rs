use anyhow::Result;
use blake2::Blake2b;
use std::env::args;
use std::fs;
use std::io::Read;
fn main() {
    let arg0 = args().nth(0).expect("need a file arg");
    if let Ok(mut file) = fs::File::open(arg0) {
        let _checksum = compute_checksum(&mut file);
        todo!()
    } else {
        panic!("no")
    }
}

const BUFFER_SIZE: usize = 1024;
fn compute_checksum<R: Read>(reader: &mut R) -> Result<Vec<u8>> {
    use blake2::digest::Digest;
    let mut hasher = Blake2b::default();
    let mut buffer = [0u8; BUFFER_SIZE];
    loop {
        let n = reader.read(&mut buffer)?;
        hasher.update(&buffer[..n]);
        if n == 0 || n < BUFFER_SIZE {
            break;
        }
    }
    Ok(Box::new(hasher).finalize().to_vec())
}
