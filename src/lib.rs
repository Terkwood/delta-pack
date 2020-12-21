use gdnative::api::*;
use gdnative::prelude::*;

#[derive(gdnative::NativeClass)]
#[inherit(Label)]
struct IncrementalPatch {
    bogus: u32,
}

#[gdnative::methods]
impl IncrementalPatch {
    fn new(_owner: &Label) -> Self {
        IncrementalPatch { bogus: 0 }
    }

    #[export]
    fn _ready(&mut self, _owner: &Label) {
        godot_print!("Hello from rust")
    }
}

fn init(handle: InitHandle) {
    handle.add_class::<IncrementalPatch>();
}

godot_init!(init);
