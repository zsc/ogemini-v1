```ocaml
module Game = struct
  type position = { x : int; y : int }

  type player = {
    name : string;
    position : position;
    health : int;
    attack : int;
    defense : int;
  }

  type item = {
    name : string;
    attack_bonus : int;
    defense_bonus : int;
    health_bonus : int;
  }

  type game_state = {
    player : player;
    items : item list;
    game_over : bool;
    message : string;
  }

  let create_player name x y =
    {
      name;
      position = { x; y };
      health = 100;
      attack = 10;
      defense = 5;
    }

  let create_item name attack_bonus defense_bonus health_bonus =
    { name; attack_bonus; defense_bonus; health_bonus }

  let initial_game_state =
    {
      player = create_player "Hero" 0 0;
      items =
        [
          create_item "Sword" 5 0 0;
          create_item "Shield" 0 5 0;
          create_item "Potion" 0 0 20;
        ];
      game_over = false;
      message = "Welcome to the game!";
    }

  let move_player game_state dx dy =
    let new_x = game_state.player.position.x + dx in
    let new_y = game_state.player.position.y + dy in
    {
      game_state with
      player =
        {
          game_state.player with
          position = { x = new_x; y = new_y };
        };
      message = "Player moved!";
    }

  let use_item game_state item_name =
    let item_option =
      List.find_opt (fun item -> item.name = item_name) game_state.items
    in
    match item_option with
    | Some item ->
        let updated_player =
          {
            game_state.player with
            attack = game_state.player.attack + item.attack_bonus;
            defense = game_state.player.defense + item.defense_bonus;
            health = game_state.player.health + item.health_bonus;
          }
        in
        let updated_items =
          List.filter (fun item -> item.name <> item_name) game_state.items
        in
        {
          game_state with
          player = updated_player;
          items = updated_items;
          message = Printf.sprintf "Used item: %s" item_name;
        }
    | None -> { game_state with message = "Item not found!" }

  let is_game_over game_state = game_state.game_over

  let get_message game_state = game_state.message
end

let () =
  print_endline "Game module compiled successfully.";
  let initial_state = Game.initial_game_state in
  print_endline initial_state.Game.message
```