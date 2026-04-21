import redis
import time
import os
import signal

r = redis.Redis(
    host=os.getenv("REDIS_HOST", "localhost"),
    port=int(os.getenv("REDIS_PORT", 6379)),
    password=os.getenv("REDIS_PASSWORD"),
)

running = True

def signal_handler(sig, frame):
    global running
    print("Shutting down...")
    running = False

signal.signal(signal.SIGINT, signal_handler)
signal.signal(signal.SIGTERM, signal_handler)

def process_job(job_id):
    print(f"Processing job {job_id}")
    time.sleep(2)  # simulate work
    r.hset(f"job:{job_id}", "status", "completed")
    print(f"Done: {job_id}")

while running:
    job = r.brpop("job", timeout=5)
    if job:
        _, job_id = job
        process_job(job_id.decode())
