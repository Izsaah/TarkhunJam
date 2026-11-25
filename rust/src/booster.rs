

use std::default;

use godot::{classes::{CharacterBody2D, INode, Node, class_macros::private::virtuals::Xrvrs::Gd}, register::{GodotClass, godot_api}};
use rand::Rng;
use godot::meta::ToGodot;

use godot::prelude::*;
use godot::classes::{Area2D, IArea2D};



#[derive(GodotClass)]
#[class(base=Area2D)]
struct Booster {
    effect: Effect,
    base: Base<Area2D>,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Default)]
enum Effect {
    #[default]
    Blind,
    Reload,
    Speed,
    Slow,
    Immortal,
}

#[godot_api]
impl IArea2D for Booster {
    fn init(base: Base<Area2D>) -> Self {
        Self {
            effect: Effect::default(),
            base,
        }
    }
}

#[godot_api]
impl Booster {
    #[func]
    fn apply_effect(&mut self, mut target: Gd<CharacterBody2D>) {
        self.effect = Effect::random();

        match self.effect {
            Effect::Blind => {
                godot_print!("Blind effect applied!");
            }

            Effect::Immortal => {
                godot_print!("Immortal effect applied!");
            }

            Effect::Reload => {
                godot_print!("Reload effect applied!");
            }

            Effect::Slow => {
                let speed = target.get("move_speed").to::<f64>();
                target.set("move_speed", &(speed * 0.5).to_variant());
            }

            Effect::Speed => {
                let speed = target.get("move_speed").to::<f64>();
                target.set("move_speed", &(speed * 1.5).to_variant());
            }
        }
    }
}

impl Effect {
    fn random() -> Self {
        let number = rand::thread_rng().gen_range(0..5);

        [
            Effect::Blind,
            Effect::Reload,
            Effect::Speed,
            Effect::Slow,
            Effect::Immortal,
        ][number]
    }
}