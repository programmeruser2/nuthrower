use std/log

let url = "https://glitch.ad"
let info = (http get ($url + "/api/info"))
let flag_format = $info.flag_format
let tick_len = $info.tick_len
let dir = $nu.home-dir | path join ".nuthrower"
let ownIp = (cat /etc/glitch/team.json|from json).ip
mkdir $dir
mkdir ($dir | path join exploits)
mkdir ($dir | path join logs)

def attack [tick: int, service: string, team: string, ip: string, flagtick: string, flagid: string] {
  let exploit = $dir | path join "exploits" $service
  if ($exploit | path exists) and (ls -l $exploit | get 0.mode | str contains "x") {
    let res = (^$exploit $ip $flagid | complete)
		let logname = $"(date now|format date)_tick_($tick)-service_($service)-team_($team)-ip_($ip)-ft_($flagtick)-id_($flagid)"
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
		let logname = $logname + $"-exitcode_($res.exit_code)"
		log info $"Exploit for ($service) executed ($message) |" --context { tick: $tick, service: $service, team: $team, ip: $ip, flag_tick: $flagtick, flagid: $flagid } 
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

def start_thrower [] {
	log info $"tick len ($tick_len)" 
	log info "starting thrower, check ~/.nuthrower/logs for logs"
	log info "add exploits to ~/.nuthrower/exploits/SERVICE (must be executable)"
	loop { 
		run_attacks
		sleep ($tick_len * 1sec)
	}
}
def import_exploit [service: string, file: string] {
	let dest = ($dir | path join exploits $service)
	cp $file $dest
	chmod +x $dest 
	print $"Successfully threw exploit ($file) for ($service) to ($dest)"
}

def remove_exploit [service: string] {
	let dest = ($dir | path join exploits $service) 
	rm $dest 
	print $"Successfully removed exploit for ($service) from ($dest)"
}

def test_exploit [service: string, exploit: string] {
	let data = http get ($url + "/api/flagids")
	let tick = $data.tick;
	let teamInfo = $data | get services | transpose num info | where info.name == "simplest" | first | get info.teams."1";
	let ip = $teamInfo.ip;
	let flagid = $teamInfo.flagids | get $"($tick)";
	let res = (^$exploit $ip $flagid) | complete; 
	mut message = ""; 
	if $res.exit_code != 0 {
		$message = $"FAIL with ($res.exit_code)" 
	} else {
		$message = $"OK with " 
		let flag = $res.stdout | parse -r ("(" + $flag_format + ")") | get capture0.0?
		if $flag == null {
			$message += "no flag"
		} else {
			$message += "flag=" + $flag 
		}
	}
	print $message 
	print "program output: "
	print "---stdout begin---" 
	print $res.stdout 
	print "---stdout end---"
	print "---stderr begin---"
	print $res.stderr
	print "---stderr end---"
}

def view_logs [target: string] {
	if target == null {
		less ($dir | path join logs nuthrower.log)
	} else {
		less ($dir | path join logs $"($target).log")
	}
}

# Thrower written in nu-shell
# Run a subcommand with --help to see specific options
def main [] {
	help main
}

# Run the thrower 
def "main run" [
	--foreground # Run the thrower in the foreground 
] {
	if $foreground {
		start_thrower 
	} else {
		let logfile = ($dir | path join logs nuthrower.log)
		touch $logfile
		exec sh -c $"exec setsid -f ($nu.current-exe) ($env.CURRENT_FILE) run --foreground > ($logfile) 2>&1 < /dev/null"
	}
}

# Import an exploit script into the thrower (overwrites existing scripts) 
def "main import" [
	service: string, # The service the exploit is for
	file: string # The file that contains the exploit 
] {
	import_exploit $service $file 
}

# Remove an exploit from the thrower 
def "main rm" [ 
	service: string # The service the exploit is for
] {
	remove_exploit $service 
}

# Test an exploit wtih the NOP team 
def "main test" [ 
	service: string, 
	exploit: string
] {
	test_exploit $service $exploit 
}

# View the logs, either for the thrower itself or for the NOP team 
def "main logs" [
	target?: string # The service you want to view the logs for. Leave blank to view the thrower logs 
] {
	view_logs $target 
}
