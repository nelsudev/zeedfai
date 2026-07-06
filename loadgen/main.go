// zeedfai loadgen: gera transações sintéticas para o Kafka a uma taxa
// configurável, com modo burst via HTTP (POST /burst?rate=2000&seconds=120).
package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"math/rand"
	"net/http"
	"os"
	"strconv"
	"strings"
	"sync/atomic"
	"time"

	"github.com/twmb/franz-go/pkg/kgo"
)

type Transaction struct {
	ID        string  `json:"id"`
	Card      string  `json:"card"`
	AmountEUR float64 `json:"amount_eur"`
	Country   string  `json:"country"`
	Timestamp int64   `json:"ts"`
}

var countries = []string{"PT", "ES", "FR", "DE", "GB", "XX", "ZZ"}

func main() {
	brokers := getenv("KAFKA_BROKERS", "localhost:9092")
	topic := getenv("KAFKA_TOPIC", "transactions")
	baseRate, _ := strconv.ParseInt(getenv("BASE_RATE", "100"), 10, 64)

	cl, err := kgo.NewClient(kgo.SeedBrokers(strings.Split(brokers, ",")...))
	if err != nil {
		log.Fatalf("kafka client: %v", err)
	}
	defer cl.Close()

	// rate em ev/s, alterável em runtime pelo endpoint de burst
	var rate atomic.Int64
	rate.Store(baseRate)

	http.HandleFunc("/burst", func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost {
			http.Error(w, "POST only", http.StatusMethodNotAllowed)
			return
		}
		burstRate, _ := strconv.ParseInt(r.URL.Query().Get("rate"), 10, 64)
		seconds, _ := strconv.ParseInt(r.URL.Query().Get("seconds"), 10, 64)
		if burstRate <= 0 || seconds <= 0 {
			http.Error(w, "usage: POST /burst?rate=2000&seconds=120", http.StatusBadRequest)
			return
		}
		rate.Store(burstRate)
		time.AfterFunc(time.Duration(seconds)*time.Second, func() {
			rate.Store(baseRate)
			log.Printf("burst over, back to %d ev/s", baseRate)
		})
		log.Printf("burst: %d ev/s for %ds", burstRate, seconds)
		fmt.Fprintf(w, "burst: %d ev/s for %ds\n", burstRate, seconds)
	})
	http.HandleFunc("/healthz", func(w http.ResponseWriter, _ *http.Request) { w.WriteHeader(200) })
	go func() { log.Fatal(http.ListenAndServe(":8081", nil)) }()

	log.Printf("loadgen: brokers=%s topic=%s base=%d ev/s", brokers, topic, baseRate)
	ctx := context.Background()
	var seq uint64
	for {
		r := rate.Load()
		tick := time.Now()
		for i := int64(0); i < r; i++ {
			seq++
			t := Transaction{
				ID:        fmt.Sprintf("tx-%d", seq),
				Card:      fmt.Sprintf("card-%04d", rand.Intn(5000)),
				AmountEUR: float64(rand.Intn(100000)) / 100,
				Country:   countries[rand.Intn(len(countries))],
				Timestamp: time.Now().UnixMilli(),
			}
			b, _ := json.Marshal(t)
			cl.Produce(ctx, &kgo.Record{Topic: topic, Value: b}, func(_ *kgo.Record, err error) {
				if err != nil {
					log.Printf("produce: %v", err)
				}
			})
		}
		if d := time.Second - time.Since(tick); d > 0 {
			time.Sleep(d)
		}
	}
}

func getenv(k, def string) string {
	if v := os.Getenv(k); v != "" {
		return v
	}
	return def
}
