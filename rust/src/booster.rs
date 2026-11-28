use std::default;

use godot::classes::{Area2D, IArea2D};
use godot::meta::ToGodot;
use godot::prelude::*;
use godot::{
    classes::{class_macros::private::virtuals::Xrvrs::Gd, CharacterBody2D, INode, Node},
    register::{godot_api, GodotClass},
};

use crate::booster::Effect::Reload;

#[derive(GodotClass)]
#[class(base=Area2D)]
pub struct Booster {
    #[export]
    shield_scene: Option<Gd<PackedScene>>,
    effect: Effect,
    base: Base<Area2D>,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Default)]
pub enum Effect {
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
            shield_scene: None,
            effect: Effect::default(),
            base,
        }
    }
}

#[godot_api]
impl Booster {
    #[func]
    fn apply_effect(&mut self, mut target: Gd<CharacterBody2D>) {
        match Reload {
            Effect::Blind => {
                // i have no idea how to implement this, so for now we just ignore it
                godot_print!("Blind effect applied!");
            }

            Effect::Immortal => {
                const SHIELD_SECONDS: f64 = 5.0;

                if let Some(mut existing) = target.get_node_or_null("Shield") {
                    existing.call("refresh_duration", &[SHIELD_SECONDS.to_variant()]);
                } else {
                    let Some(scene) = self.shield_scene.as_ref() else {
                        return;
                    };
                    let Some(mut shield) = scene.try_instantiate_as::<Area2D>() else {
                        godot_error!("Could not instantiate shield scene");
                        return;
                    };
                    shield.set_name("Shield");

                    shield.set_position(Vector2::ZERO);
                    shield.call("refresh_duration", &[SHIELD_SECONDS.to_variant()]);
                    target.call_deferred(
                        "add_child",
                        &[shield.clone().upcast::<Node>().to_variant()],
                    );
                }
                godot_print!("Immortal effect applied!");
            }

            Effect::Reload => {
                const RELOAD_AMMO: i64 = 20;

                if let Some(mut weapon) = target.get_node_or_null("HeadPivot/WeaponMuzzle") {
                    weapon.call("add_ammo", &[RELOAD_AMMO.to_variant()]);
                    godot_print!("Reload effect applied: added {RELOAD_AMMO} ammo.");
                } else {
                    godot_error!("Could not find the player's weapon to reload");
                }
            }

            Effect::Slow => {
                let speed = target.get("move_speed").to::<f64>();
                target.set("move_speed", &(speed * 0.5).to_variant());
                godot_print!("Slow effect applied!");
            }

            Effect::Speed => {
                let speed = target.get("move_speed").to::<f64>();
                target.set("move_speed", &(speed * 1.5).to_variant());
                godot_print!("Speed effect applied!");
            }
        }
    }

    #[func]
    fn set_effect(&mut self, effect_id: i64) {
        self.effect = match effect_id {
            0 => Effect::Blind,
            1 => Effect::Reload,
            2 => Effect::Speed,
            3 => Effect::Slow,
            4 => Effect::Immortal,
            _ => {
                godot_error!("Booster received unknown effect ID: {effect_id}");
                return;
            }
        };
    }
}

impl Effect {
    pub(crate) fn id(self) -> i64 {
        match self {
            Effect::Blind => 0,
            Effect::Reload => 1,
            Effect::Speed => 2,
            Effect::Slow => 3,
            Effect::Immortal => 4,
        }
    }
}
