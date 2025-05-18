package main

/*
#include <stdlib.h>
*/
import "C"

import (
	"bufio"
	"context"
	"crypto/tls"
	"fmt"
	"log"
	"os"
	"strings"
	"time"

	"cloud.google.com/go/pubsub"
	"google.golang.org/api/option"
	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials"
)

var (
	projectID string
	topicID   string
)

func loadEnv(filePath string) error {
	file, err := os.Open(filePath)
	if err != nil {
		return fmt.Errorf("erro ao abrir o arquivo %s: %v", filePath, err)
	}
	defer file.Close()

	scanner := bufio.NewScanner(file)
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		parts := strings.SplitN(line, "=", 2)
		if len(parts) != 2 {
			continue
		}
		key := strings.TrimSpace(parts[0])
		value := strings.TrimSpace(parts[1])
		os.Setenv(key, value)
	}
	if err := scanner.Err(); err != nil {
		return fmt.Errorf("erro ao ler o arquivo %s: %v", filePath, err)
	}
	return nil
}

func init() {
	if err := loadEnv(".env"); err != nil {
		log.Printf("Erro ao carregar .env: %v", err)
	}

	projectID = os.Getenv("PUBSUB_PROJECT_ID")
	topicID = os.Getenv("PUBSUB_TOPIC_ID")

	if projectID == "" || topicID == "" {
		log.Printf("As variáveis PUBSUB_PROJECT_ID e/ou PUBSUB_TOPIC_ID não estão definidas no .env")
	}
}

func publishMessage(message string) error {
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	creds := credentials.NewTLS(&tls.Config{InsecureSkipVerify: true})
	client, err := pubsub.NewClient(ctx, projectID,
		option.WithGRPCDialOption(grpc.WithTransportCredentials(creds)))
	if err != nil {
		return fmt.Errorf("erro ao criar o cliente Pub/Sub: %v", err)
	}
	defer client.Close()

	topic := client.Topic(topicID)
	result := topic.Publish(ctx, &pubsub.Message{
		Data: []byte(message),
	})
	id, err := result.Get(ctx)
	if err != nil {
		return fmt.Errorf("erro ao publicar mensagem: %v", err)
	}

	fmt.Printf("Mensagem publicada com sucesso. ID: %v\n", id)
	return nil
}

//export PublishMessage
func PublishMessage(cMessage *C.char) C.int {
	message := C.GoString(cMessage)
	err := publishMessage(message)
	if err != nil {
		log.Printf("Erro ao publicar mensagem: %v", err)
		return 1
	}
	return 0
}

func main() {}
