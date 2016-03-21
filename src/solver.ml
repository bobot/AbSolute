open Apron
open Mpqf
open Format
open Utils
open ADCP

module Solve(Abs : AbstractCP) =
  struct
    module T = Apron_domain.SyntaxTranslator(Abs)

    let man = Abs.get_manager

    let consistency abs tab =
      let abs' = Abstract1.meet_tcons_array man abs tab in
      (if Abstract1.is_bottom man abs' then `Empty
       else 
	  if tcons_for_all (Abstract1.sat_tcons man abs') tab then `Full
	  else `Maybe),abs'
	  
    let draw abs info col vars =
      if !Constant.visualization then 
	Vue.draw (Abs.points_to_draw abs vars) col info

    let explore abs env tab nb_steps nb_sol vars =
      Format.printf "solving begins\n%!";
      let info = Vue.get_info (Abs.points_to_draw abs vars) in
      Format.printf "points to draw done\n%!";
      draw abs info Graphics.yellow vars;
      let rec aux abs env nb_steps nb_sol =
	let cons,abs' = consistency abs tab in	
	match cons with
	| `Empty -> (nb_steps, nb_sol)
	| `Full -> 
	  draw abs' info Graphics.blue vars; 
	  (nb_steps, nb_sol+1)
	| `Maybe  ->
	  (match (Abs.is_small abs' !Constant.precision) with
	  | true,_ -> 
	    draw abs' info Graphics.green vars;
	    (nb_steps, nb_sol+1)
	  | _,exprs when nb_sol <= !Constant.max_sol ->
	    draw abs' info Graphics.yellow vars;
            Abs.split abs' exprs |>
            List.fold_left (fun (a, b) c -> aux c env (a+1) b) (nb_steps, nb_sol)
	  | _ -> (nb_steps, nb_sol)
	  )
      in aux abs env nb_steps nb_sol

    let explore_breath_first abs env tab nb_steps nb_sol vars=
      let info = Vue.get_info (Abs.points_to_draw abs vars) in
      let nb_steps = ref nb_steps and nb_sol = ref nb_sol in
      let queue = Queue.create () in
      draw abs info Graphics.yellow vars;
      Queue.add abs queue;
      while Queue.is_empty queue |> not do
	let cons,abs' = consistency (Queue.take queue) tab in
	match cons with
	| `Empty -> ()
	| `Full -> draw abs' info Graphics.blue vars; incr nb_sol
	| `Maybe  ->
	  (match (Abs.is_small abs' !Constant.precision) with
	  | true,_ -> draw abs' info Graphics.green vars; incr nb_sol
	  | _,exprs when !nb_sol < !Constant.max_sol ->
	    draw abs' info Graphics.yellow vars;
            Abs.split abs' exprs |> List.iter (fun e -> incr nb_steps; Queue.add e queue)
	  | _ -> draw abs' info Graphics.green vars
	  )
      done;
      !nb_steps,!nb_sol

    let solving env domains cons vars=
      
      let abs = Abs.of_lincons_array env domains in
      printf "abs = %a@." Abstract1.print abs;
      let box = Abstract1.to_box man abs in
      let tab = box.Abstract1.interval_array in
      printf "box = %a@." (print_array Interval.print) tab;
      let s = Manager.get_funopt man Manager.Funid_meet_tcons_array in
      let s' = {s with Manager.algorithm = 100} in
      Manager.set_funopt man Manager.Funid_meet_tcons_array s';
      if not (Abstract1.is_bottom man abs) then
        let (nb_steps, nb_sol) = explore abs env cons 1 0 vars in
	Format.printf "solving ends\n%!";
	match nb_sol with
	| 0 -> printf "No solutions - #created nodes: %d@." nb_steps
	| 1 -> printf "Unique solution - #created nodes: %d@." nb_steps
        | _ -> printf "#solutions: %d - #created nodes: %d@." nb_sol nb_steps
      else
        printf "No Solutions - #created nodes: 0@."

    let solving solving_problem =
      let open Syntax in
      let (env, domains, _, constraints, _, _) = T.to_apron solving_problem in
      solving env domains constraints solving_problem.to_draw
  end

module Box = Solve(BoxCP)
module Oct = Solve(OctBoxCP)
module Poly = Solve(PolyCP)
