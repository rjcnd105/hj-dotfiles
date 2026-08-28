// homelab-appctl: nix-dots homelab의 앱 릴리스 배포 어댑터.
// argv ABI, /etc/homelab-apps 메타데이터, /var/lib/homelab-appctl 기록 경로는
// 이전 셸 구현과 호환된다. deploy는 검증→pull→tag→migrate→단일 restart→smoke→
// 기록→retention 트랜잭션이다.
package main

import (
	"fmt"
	"os"
)

const usageText = `Usage:
  homelab-appctl list
  homelab-appctl status <app> <channel>
  homelab-appctl smoke <app> <channel>
  homelab-appctl deploy <app> <channel> --target <release-id> [--dry-run]
  homelab-appctl logs <app> <channel>
`

func die(err error) {
	fmt.Fprintf(os.Stderr, "homelab-appctl: %v\n", err)
	os.Exit(1)
}

func main() {
	args := os.Args[1:]
	if len(args) == 0 {
		fmt.Print(usageText)
		return
	}

	switch args[0] {
	case "-h", "--help", "help":
		fmt.Print(usageText)
	case "list":
		if len(args) != 1 {
			die(fmt.Errorf("list takes no arguments"))
		}
		if err := cmdList(); err != nil {
			die(err)
		}
	case "status", "smoke", "logs":
		if len(args) != 3 {
			fmt.Fprint(os.Stderr, usageText)
			os.Exit(1)
		}
		meta, err := loadMetadata(args[1], args[2])
		if err != nil {
			die(err)
		}
		switch args[0] {
		case "status":
			err = cmdStatus(meta)
		case "smoke":
			err = cmdSmoke(meta)
		case "logs":
			err = cmdLogs(meta)
		}
		if err != nil {
			die(err)
		}
	case "deploy":
		if len(args) < 3 {
			fmt.Fprint(os.Stderr, usageText)
			os.Exit(1)
		}
		app, channel := args[1], args[2]
		dryRun := false
		target := ""
		rest := args[3:]
		for len(rest) > 0 {
			switch rest[0] {
			case "--dry-run":
				dryRun = true
				rest = rest[1:]
			case "--target":
				if len(rest) < 2 {
					die(fmt.Errorf("--target requires a value"))
				}
				if err := requireTarget(rest[1]); err != nil {
					die(err)
				}
				target = rest[1]
				rest = rest[2:]
			default:
				die(fmt.Errorf("unknown deploy option: %s", rest[0]))
			}
		}
		if target == "" {
			die(fmt.Errorf("deploy requires --target <release-id>"))
		}
		meta, err := loadMetadata(app, channel)
		if err != nil {
			die(err)
		}
		if dryRun {
			err = cmdDeployDryRun(meta, app, channel, target)
		} else {
			err = cmdDeploy(meta, app, channel, target)
		}
		if err != nil {
			die(err)
		}
	default:
		fmt.Fprint(os.Stderr, usageText)
		os.Exit(1)
	}
}
