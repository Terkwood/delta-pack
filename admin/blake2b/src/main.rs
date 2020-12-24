use std::env::args;
use std::fs;
fn main() {
    let arg0 = args().nth(0).expect("need a file arg");
    if let Ok(mut file) = fs::File::open(arg0) {
        todo!()
    } else {
        panic!("no")
    }
}
