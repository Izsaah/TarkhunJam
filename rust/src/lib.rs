use godot::{classes::gdextension, prelude::*};

struct MyExtension;

#[gdextension]
unsafe impl ExtensionLibrary for MyExtension {}
mod booster;
mod booster_spawner;
mod shield;
