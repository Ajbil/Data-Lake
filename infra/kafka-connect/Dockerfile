FROM quay.io/debezium/connect@sha256:f062d06e19be455ebf43cca662747f2ab6efbe4678954e7d64ac06055b8c7aff

# KAFKA-16217: 3.7.0 can loop forever closing a timed-out transaction.
# Keep the existing Debezium/Connect runtime; apply only the compatible client patch.
USER root
RUN curl --fail --silent --show-error --location --retry 3 \
      https://repo.maven.apache.org/maven2/org/apache/kafka/kafka-clients/3.7.2/kafka-clients-3.7.2.jar \
      --output /kafka/libs/kafka-clients-3.7.2.jar \
    && echo '59ab767afeb15a97ce3663b784677568ccc73180d33b2474a313e3acdcf320e6767feaa704f4dba399f2d7f0ad6bd46a5c26b23b979b24049728e93e55ff665c  /kafka/libs/kafka-clients-3.7.2.jar' | sha512sum --check --strict \
    && rm /kafka/libs/kafka-clients-3.7.0.jar \
    && chown kafka:kafka /kafka/libs/kafka-clients-3.7.2.jar
USER kafka
