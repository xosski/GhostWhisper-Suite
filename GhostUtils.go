package main

import (
	"fmt"
	"io"
	"log"
	"os"
	"strconv"
	"strings"
)

type Info struct {
	start, end int
}

func main() {
	// Open the file
	f, err := os.Open("tinput.txt")
	if err != nil {
		log.Fatalf("Error opening file: %s", err)
	}
	defer f.Close()

	// Read the entire file into memory
	bytes, err := io.ReadAll(f)
	if err != nil {
		log.Fatalf("Error reading file: %s", err)
	}
	input := string(bytes)

	// Split the input by spaces to get the numbers
	numsStr := strings.Split(input, " ")

	// Create a new linked list
	list := &LinkedList{}
	fmt.Println("Initial Input:", numsStr)

	// Add numbers to the linked list
	for _, numStr := range numsStr {
		num, err := strconv.ParseUint(numStr, 10, 32)
		if err != nil {
			log.Fatalf("Error parsing number: %s", err)
		}
		list.AddTail(uint32(num))
	}

	// Process the list for 10 iterations
	for i := 0; i < 10; i++ {
		current := list.head
		for current != nil {
			if current.value == 0 {
				current.value = 1
			} else if current.HasEvenDigits() {
				list.Replace(current)
			} else {
				current.value *= 2024
			}
			current = current.next
		}
		list.PrintLinkedList()
	}
}

// Node represents an element in the linked list
type Node struct {
	value    uint32
	previous *Node
	next     *Node
}

// HasEvenDigits checks if the node's value has an even number of digits
func (n *Node) HasEvenDigits() bool {
	str := fmt.Sprintf("%d", n.value)
	return len(str)%2 == 0
}

// Replace splits the node's value into two new nodes
func (n *Node) Replace() (*Node, *Node) {
	numStr := fmt.Sprintf("%d", n.value)
	mid := len(numStr) / 2
	num1, _ := strconv.ParseInt(numStr[:mid], 10, 64)
	num2, _ := strconv.ParseInt(numStr[mid:], 10, 64)

	// Create new nodes for the split value
	newNode1 := &Node{value: uint32(num1), previous: n.previous}
	if n.previous != nil {
		n.previous.next = newNode1
	}

	newNode2 := &Node{value: uint32(num2), next: n.next}
	if n.next != nil {
		n.next.previous = newNode2
	}

	// Link the new nodes together
	newNode1.next = newNode2
	newNode2.previous = newNode1
	return newNode1, newNode2
}

// LinkedList represents a doubly linked list
type LinkedList struct {
	head   *Node
	tail   *Node
	length int
}

// Replace handles replacing a node in the list
func (ll *LinkedList) Replace(current *Node) {
	node, node2 := current.Replace()
	if ll.head == current {
		ll.head = node
	} else if ll.tail == current {
		ll.tail = node2
	}
	ll.length++
}

// AddTail adds a new node with a given value to the end of the list
func (ll *LinkedList) AddTail(value uint32) {
	node := &Node{value: value}
	if ll.tail == nil {
		ll.head = node
		ll.tail = node
	} else {
		ll.tail.next = node
		node.previous = ll.tail
		ll.tail = node
	}
	ll.length++
}

// PrintLinkedList prints all the values in the linked list
func (ll LinkedList) PrintLinkedList() {
	current := ll.head
	for current != nil {
		fmt.Printf("%d ", current.value)
		current = current.next
	}
	fmt.Println()
}

// ==============================================

// BinaryHeap represents a min-heap
type BinaryHeap struct {
	array []int
	size  int
}

// NewBinaryHeap creates a new BinaryHeap
func NewBinaryHeap() *BinaryHeap {
	return &BinaryHeap{}
}

// Insert adds a value to the heap
func (h *BinaryHeap) Insert(value int) {
	h.array = append(h.array, value)
	h.size++
	h.percolateUp(h.size - 1)
}

// Delete removes the smallest element from the heap
func (h *BinaryHeap) Delete() int {
	if h.size == 0 {
		panic("Heap is empty")
	}

	min := h.array[0]
	h.array[0] = h.array[h.size-1]
	h.array = h.array[:h.size-1]
	h.size--
	h.percolateDown(0)

	return min
}

// percolateUp moves an element up the heap to restore heap property
func (h *BinaryHeap) percolateUp(index int) {
	parentIndex := (index - 1) / 2

	for index > 0 && h.array[index] < h.array[parentIndex] {
		h.array[index], h.array[parentIndex] = h.array[parentIndex], h.array[index]
		index = parentIndex
		parentIndex = (index - 1) / 2
	}
}

// percolateDown moves an element down the heap to restore heap property
func (h *BinaryHeap) percolateDown(index int) {
	for {
		leftChildIndex := 2*index + 1
		rightChildIndex := 2*index + 2
		smallestIndex := index

		if leftChildIndex < h.size && h.array[leftChildIndex] < h.array[smallestIndex] {
			smallestIndex = leftChildIndex
		}

		if rightChildIndex < h.size && h.array[rightChildIndex] < h.array[smallestIndex] {
			smallestIndex = rightChildIndex
		}

		if smallestIndex == index {
			break
		}

		h.array[index], h.array[smallestIndex] = h.array[smallestIndex], h.array[index]
		index = smallestIndex
	}
}
