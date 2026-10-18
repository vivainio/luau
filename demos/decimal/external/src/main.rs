// Runs a Luau script (see README.md in this directory) with the mlua-decimal global `D` installed, and reports memory around a script phase.
use mlua::Lua;
use std::time::Instant;

fn main() -> mlua::Result<()> {
    let args: Vec<String> = std::env::args().collect();
    let path = &args[1];
    let src = std::fs::read_to_string(path).expect("read script");
    let lua = Lua::new();
    mlua_decimal::install(&lua)?;
    // memory helpers for the scripts
    let used = lua.create_function(|lua, ()| Ok(lua.used_memory() as f64))?;
    lua.globals().set("used_memory", used)?;
    let gc = lua.create_function(|lua, ()| { lua.gc_collect()?; lua.gc_collect()?; Ok(()) })?;
    lua.globals().set("gc_collect", gc)?;
    let t = Instant::now();
    match lua.load(&src).set_name("=script").exec() {
        Ok(()) => {}
        Err(e) => { eprintln!("error: {e}"); std::process::exit(1); }
    }
    eprintln!("(total {:.0} ms)", t.elapsed().as_secs_f64() * 1000.0);
    Ok(())
}
