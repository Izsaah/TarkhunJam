use godot::prelude::*;

struct MyExtension;

#[gdextension]
unsafe impl ExtensionLibrary for MyExtension {}

#[derive(GodotClass)]
#[class(base=Node)]
pub struct RustPlayer {
    node: Base<Node>,
}

#[godot_api]
impl INode for RustPlayer {
    fn init(node: Base<Node>) -> Self {
        godot_print!("RustPlayer initialized from Rust via GDExtension!");
        Self { node }
    }

    fn ready(&mut self) {
        godot_print!("RustPlayer is ready!");
    }
}
