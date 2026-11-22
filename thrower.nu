let url = "https://intro.glitch.ad"
let info = (http get ($url+"/api/info"))
let flag_format = $info.flag_format
let tick_len = $info.tick_len 
def attack [tick: string, service: string, team: string, ip: string, flagtick: string, flagid: string] {
  let exploit = $nu.home_dir | path join "nuthrower" "exploits" $service
  if ($exploit | path exists) and (ls -l /usr/bin/ls | get 0.mode | str contains "x") {
    let res = (^$exploit | complete)
    let logname = $"tick_($tick)-service_($service)-team_($team)-ip_($ip)-ft_($flagtick)-id_($flagid)"
    mut message = ""
    if $res.exit_code != 0 {
      $message = $"fail tick ($logname)" 
    } else {
      $message = $"ok tick ($logname)" 
      $flag = $res.stdout | parse -r ("(" + flag_format + ")") | get capture0.0?
      if $flag == null {
        $message += " no flag"
      } else {
        $message += "flag=" + $flag 
      }
    }
    $message += "\n"
    $message | save --append ~/nuthrower/logs/nuthrower.log 
    ($"---stdout ($logname)---\n" + $res.stdout + $"\n---stderr ($logname)---\n" + $res.stderr + "\n---end ($logname)---\n") | save --append ($nu.home_dir | path join "nuthrower" "logs" $service ".log")
  }
}
def run_attacks [] {
	let flagids = (http get ($url+"/api/flagids"))
	let services = $flagids.tick
	for service in ($services | transpose num info) {
		for team in ($service.info.teams | transpose num info) {
			let name = $service.info.name 
			let team = $team.info.name
			let ip = $team.info.ip 
			let flags = $team.info.flagids
			for flag in ($flags | transpose num id) {
				job spawn { attack $flagids.tick $name $team $ip $flag.num $flag.id }
			}
		}
	}
}

mkdir -p ~/nuthrower
mkdir -p ~/nuthrower/exploits
mkdir -p ~/nuthrower/logs
touch ~/nuthrower/logs/nuthrower.log 
job spawn { run_attacks; sleep $tick_len * 1sec }
