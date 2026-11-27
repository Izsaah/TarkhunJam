use godot::classes::{Area2D, IArea2D, Node};
use godot::prelude::*;

#[derive(GodotClass)]
#[class(base=Area2D)]
struct Shield {
    timer: f64,
    base: Base<Area2D>,
}

#[godot_api]
impl IArea2D for Shield {
    fn init(base: Base<Area2D>) -> Self {
        Self { timer: 50.0, base }
    }
    fn process(&mut self, delta: f64) {
        self.timer -= delta;
        if self.timer <= 0.0 {
            self.base_mut().queue_free();
        }
    }
}

#[godot_api]
impl Shield {
    #[func]
    fn take_damage(&mut self, _damage: i64, _instant_kill: bool, _source: Option<Gd<Node>>) {}

    #[func]
    fn refresh_duration(&mut self, second: f64) {
        self.timer = second.max(0.0);
    }
}
