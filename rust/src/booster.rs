

use std::default;

use godot::{classes::{CharacterBody2D, INode, Node, class_macros::private::virtuals::Xrvrs::Gd}, register::{GodotClass, godot_api}};
use rand::Rng;
use godot::meta::ToGodot;


#[derive(GodotClass)]
#[class(base=Node,init)]
struct Booster{
_effect: Effect,
_target: Option<Gd<CharacterBody2D>>,

}
#[derive(Debug, Clone, Copy, PartialEq, Eq, Default)]
enum Effect {
#[default]    
_BLIND,_RELOAD,_SPEED,_SLOW,_IMMORTAL
}
#[godot_api]
impl Booster{
    #[func]
    pub fn _apply_effect(&mut self,mut target: Gd<CharacterBody2D>){
        self._effect=Effect::_random();
        
        match self._effect {
            Effect::_BLIND => {
                print!("Blind effect applied to {:?}", target);
            },Effect::_IMMORTAL=>{
                print!("Immortal effect applied to {:?}", target);
            },Effect::_RELOAD=>{
                print!("Reload effect applied to  {:?}",target);
            },Effect::_SLOW=>{
                let speed = target.get("move_speed").to::<f64>();
                print!("Slow effect applied to {:?}", target.set("move_speed", &(speed*0.5).to_variant()));
            },Effect::_SPEED=>{
                let  speed = target.get("move_speed").to::<f64>();
                print!("Speed effect applied to {:?}", target.set("move_speed", &(speed*1.5).to_variant()));
            }
        }
    }
}
impl Effect{
    fn _random()-> Self{
        let number=rand::thread_rng().gen_range(0..5);
        let effect=[Effect::_BLIND,Effect::_RELOAD,Effect::_SPEED,Effect::_SLOW,Effect::_IMMORTAL];
        effect[number]
    }    
}

