import java.lang.reflect.Field;
import java.util.Properties;
import org.apache.kafka.clients.producer.KafkaProducer;
import org.apache.kafka.common.utils.AppInfoParser;

// Reproduce KAFKA-16217 without a live broker or changing any pipeline offsets.
public class KafkaCloseRegression {
    @SuppressWarnings({"rawtypes", "unchecked"})
    public static void main(String[] args) throws Exception {
        Properties config = new Properties();
        config.put("bootstrap.servers", "127.0.0.1:1");
        config.put("transactional.id", "mbs-close-regression");
        config.put("key.serializer", "org.apache.kafka.common.serialization.StringSerializer");
        config.put("value.serializer", "org.apache.kafka.common.serialization.StringSerializer");
        KafkaProducer<String, String> producer = new KafkaProducer<>(config);
        Field managerField = KafkaProducer.class.getDeclaredField("transactionManager");
        managerField.setAccessible(true);
        Object manager = managerField.get(producer);
        synchronized (manager) {
            // Inject the exact state left by a commit timeout, then use the real close path.
            Field state = manager.getClass().getDeclaredField("currentState");
            state.setAccessible(true);
            state.set(manager, Enum.valueOf((Class<Enum>) state.getType(), "READY"));
            producer.beginTransaction();
            Field started = manager.getClass().getDeclaredField("transactionStarted");
            started.setAccessible(true);
            started.setBoolean(manager, true);
            manager.getClass().getMethod("beginCommit").invoke(manager);
            Field requests = manager.getClass().getDeclaredField("pendingRequests");
            requests.setAccessible(true);
            ((java.util.Queue<?>) requests.get(manager)).clear();
            state.set(manager, Enum.valueOf((Class<Enum>) state.getType(), "ABORTABLE_ERROR"));
        }
        Thread closing = new Thread(() -> producer.close(), "regression-close");
        closing.setDaemon(true);
        long start = System.nanoTime();
        closing.start();
        closing.join(3000);
        boolean stuck = closing.isAlive();
        System.out.printf("Kafka %s: close %s (%.3fs)%n", AppInfoParser.getVersion(),
            stuck ? "STUCK: KAFKA-16217 reproduced" : "completed",
            (System.nanoTime() - start) / 1e9);
        System.exit(stuck ? 1 : 0);
    }
}
