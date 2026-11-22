let url = "https://glitch.ad"
let info = (http get ($url + "/api/info"))
let flag_format = $info.flag_format
let tick_len = $info.tick_len
let dir = $nu.home-dir | path join ".nuthrower"
let ownIp = (cat /etc/glitch/team.json|from json).ip
def attack [tick: int, service: string, team: string, ip: string, flagtick: string, flagid: string] {
  let exploit = $dir | path join "exploits" $service
  if ($exploit | path exists) and (ls -l $exploit | get 0.mode | str contains "x") {
    let res = (^$exploit $ip $flagid | complete)
    let logname = $"tick_($tick)-service_($service)-team_($team)-ip_($ip)-ft_($flagtick)-id_($flagid)"
    mut message = ""
    if $res.exit_code != 0 {
      $message = $"FAIL with ($res.exit_code)" 
    } else {
      $message = $"OK with " 
      let flag = $res.stdout | parse -r ("(" + $flag_format + ")") | get capture0.0?
      if $flag == null {
        $message += "no flag"
      } else {
        $message += "flag=" + $flag + " "
				let submitRes = ({flags:[$flag]} | http post -t application/json ($url + "/api/submit")).flags|transpose flag code|first|get code
				$message += $"code=($submitRes.code) status=($submitRes.status)"
      }
    }
		log info $"Exploit for ($service) executed ($message)|" --context { tick: $tick, service: $service, team: $team, ip: $ip, flag_tick: $flagtick, flagid: $flagid } 
    ($"---stdout ($logname)---\n" + $res.stdout + $"\n---stderr ($logname)---\n" + $res.stderr + "\n---end ($logname)---\n") | save --append ($dir | path join "logs" $"($service).log")
  }
}
def run_attacks [] {
	let flagids = (http get $"($url)/api/flagids")
	log info $"tick ($flagids.tick)"
	let services = $flagids.services
	for service in ($services | transpose num info) {
		for team in ($service.info.teams | transpose num info) {
			let name = $service.info.name 
			let teamName = $team.info.name
			let ip = $team.info.ip 
			if $ip == $ownIp {
				continue
			}
			let flags = $team.info.flagids
			for flag in ($flags | transpose num id) {
				job spawn { attack $flagids.tick $name $teamName $ip $flag.num $flag.id }
			}
		}
	}
}

mkdir $dir
mkdir ($dir | path join exploits)
mkdir ($dir|path join logs)
log info $"tick len ($tick_len)" 
log info "starting thrower, check ~/.nuthrower/logs for logs"
log info "add exploits to ~/.nuthrower/exploits/SERVICE (must be executable)"
loop { 
	run_attacks
	sleep ($tick_len * 1sec)
}

