use crate::booster::Effect;
use godot::classes::*;
use godot::prelude::*;
use rand::seq::SliceRandom;
use rand::Rng;
use std::f64::consts::TAU;
use std::time::Duration;

#[derive(GodotClass)]
#[class(base=Node2D)]
struct BoosterSpawner {
    init_delay: Duration,
    timer_to_spawn: Duration,
    spawn_interval: Duration,
    effect_bag: EffectBag,
    base: Base<Node2D>,
    #[export]
    booster_scene: Option<Gd<PackedScene>>,
    #[export]
    player: Option<Gd<CharacterBody2D>>,
    #[export]
    spawn_radius: f32,
}
#[godot_api]
impl INode2D for BoosterSpawner {
    fn init(base: Base<Node2D>) -> Self {
        Self {
            init_delay: Duration::from_secs(10),
            timer_to_spawn: Duration::from_secs(10),
            spawn_interval: Duration::from_secs(5),
            effect_bag: EffectBag::default(),
            base,
            booster_scene: None,
            player: None,
            spawn_radius: 120.0,
        }
    }
    fn process(&mut self, delta: f64) {
        let center = match self.player.as_ref() {
            Some(player) if player.is_instance_valid() => player.get_global_position(),
            _ => self.base().get_global_position(),
        };
        self.init_delay = self
            .init_delay
            .saturating_sub(Duration::from_secs_f64(delta));
        if self.init_delay.is_zero() {
            self.timer_to_spawn = self
                .timer_to_spawn
                .saturating_sub(Duration::from_secs_f64(delta));
            if self.timer_to_spawn.is_zero() {
                let Some(scene) = self.booster_scene.as_ref() else {
                    godot_error!("Booster scene is not assigned");
                    return;
                };

                let Some(mut pickup) = scene.try_instantiate_as::<Area2D>() else {
                    godot_error!("Could not instantiate booster scene");
                    return;
                };
                self.timer_to_spawn = self.spawn_interval;
                let effect = self.effect_bag.next();
                pickup.call("set_effect", &[effect.id().to_variant()]);

                let mut rng = rand::thread_rng();
                let angle = rng.gen_range(0_f32..=TAU as f32);
                let distance = rng.gen_range(0_f32..1_f32).sqrt() * self.spawn_radius;

                let offset = Vector2::new(angle.cos() * distance, angle.sin() * distance);
                let spawn_position = center + offset;

                self.base_mut().add_child(&pickup.clone().upcast::<Node>());
                pickup.set_global_position(spawn_position);
            }
        }
    }
}

#[derive(Default)]
pub struct EffectBag {
    effect_bag: Vec<Effect>,
}

impl EffectBag {
    fn next(&mut self) -> Effect {
        if self.effect_bag.is_empty() {
            self.effect_bag = vec![
                Effect::Blind,
                Effect::Reload,
                Effect::Speed,
                Effect::Slow,
                Effect::Immortal,
            ];
            let mut rng = rand::thread_rng();
            self.effect_bag.shuffle(&mut rng);
        }
        self.effect_bag.pop().expect("bag")
    }
}
