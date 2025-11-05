===========================
🐇 RABBITMQ + SPRING BOOT (Windows to Windows)
===========================

GOAL:
-----
System A → runs RabbitMQ server
System B → runs Spring Boot app that connects remotely to System A
System A will also run another instance of the same Spring Boot project.

---------------------------
SYSTEM A — RABBITMQ SERVER
---------------------------

1️⃣ INSTALL ERLANG & RABBITMQ
-----------------------------
- Download Erlang: https://www.erlang.org/downloads
  → Install with default options.

- Download RabbitMQ: https://www.rabbitmq.com/download.html
  → Run installer (rabbitmq-server-x.x.x.exe)

Check service:
  PowerShell (Admin):
    Get-Service rabbitmq
  Start it if stopped:
    Start-Service rabbitmq


2️⃣ ENABLE MANAGEMENT CONSOLE
-----------------------------
PowerShell (Admin):
    rabbitmq-plugins enable rabbitmq_management

Open in browser:
    http://localhost:15672/
Login:
    user: guest
    pass: guest


3️⃣ CREATE REMOTE USER
----------------------
PowerShell (Admin):
    rabbitmqctl add_user springuser springpass
    rabbitmqctl set_user_tags springuser administrator
    rabbitmqctl set_permissions -p / springuser ".*" ".*" ".*"


4️⃣ CONFIGURE RABBITMQ TO LISTEN ON ALL IPs
--------------------------------------------
Edit or create this file:

  C:\Users\<YourUser>\AppData\Roaming\RabbitMQ\rabbitmq.conf
  OR
  C:\ProgramData\RabbitMQ\rabbitmq.conf

Add lines:

  listeners.tcp.default = 5672
  loopback_users.guest = false

Restart RabbitMQ:
  net stop RabbitMQ
  net start RabbitMQ


5️⃣ OPEN FIREWALL PORTS
-----------------------
PowerShell (Admin):

  netsh advfirewall firewall add rule name="RabbitMQ AMQP" dir=in action=allow protocol=TCP localport=5672
  netsh advfirewall firewall add rule name="RabbitMQ Management" dir=in action=allow protocol=TCP localport=15672


6️⃣ GET SERVER IP
-----------------
PowerShell:
  ipconfig
Example:
  IPv4 Address . . . . . . . . . . : 192.168.1.10
(Remember this IP for System B.)

---------------------------
SYSTEM B — SPRING BOOT APP
---------------------------

1️⃣ CREATE SPRING BOOT PROJECT
------------------------------
Go to https://start.spring.io
Select:
  - Spring Web
  - Spring Boot Starter AMQP
Download and extract project.


2️⃣ ADD RABBITMQ CONFIG
-----------------------
In src/main/resources/application.yml:

  spring:
    rabbitmq:
      host: 192.168.1.10   # IP of System A
      port: 5672
      username: springuser
      password: springpass

(or in application.properties)
  spring.rabbitmq.host=192.168.1.10
  spring.rabbitmq.port=5672
  spring.rabbitmq.username=springuser
  spring.rabbitmq.password=springpass


3️⃣ ADD DEPENDENCY
------------------
If missing, in pom.xml:

  <dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-amqp</artifactId>
  </dependency>


4️⃣ CREATE RABBIT CONFIG
------------------------
src/main/java/com/example/demo/RabbitConfig.java

  package com.example.demo;

  import org.springframework.amqp.core.Queue;
  import org.springframework.context.annotation.Bean;
  import org.springframework.context.annotation.Configuration;

  @Configuration
  public class RabbitConfig {
      @Bean
      public Queue demoQueue() {
          return new Queue("demoQueue", true); // durable queue
      }
  }


5️⃣ CREATE MESSAGE CONTROLLER
-----------------------------
src/main/java/com/example/demo/MessageController.java

  package com.example.demo;

  import org.springframework.amqp.rabbit.core.RabbitTemplate;
  import org.springframework.web.bind.annotation.*;

  @RestController
  @RequestMapping("/send")
  public class MessageController {

      private final RabbitTemplate rabbitTemplate;

      public MessageController(RabbitTemplate rabbitTemplate) {
          this.rabbitTemplate = rabbitTemplate;
      }

      @GetMapping("/{msg}")
      public String sendMessage(@PathVariable String msg) {
          rabbitTemplate.convertAndSend("demoQueue", msg);
          return "Sent message: " + msg;
      }
  }


6️⃣ CREATE MESSAGE LISTENER
---------------------------
src/main/java/com/example/demo/MessageListener.java

  package com.example.demo;

  import org.springframework.amqp.rabbit.annotation.RabbitListener;
  import org.springframework.stereotype.Component;

  @Component
  public class MessageListener {

      @RabbitListener(queues = "demoQueue")
      public void receive(String message) {
          System.out.println("Received: " + message);
      }
  }


7️⃣ RUN THE APP
---------------
In PowerShell or CMD:
  mvn spring-boot:run

or (if Gradle)
  ./gradlew bootRun


8️⃣ TEST CONNECTION
-------------------
On System B, open:
  http://localhost:8080/send/HelloRabbit

Result:
  Console shows → "Received: HelloRabbit"

Check in browser on System A:
  http://192.168.1.10:15672
  (Login: springuser / springpass)
  → Queues → demoQueue → verify messages.

✅ SUCCESS!
-----------
RabbitMQ on System A now receives and sends messages to Spring Boot app on System B.
Both System A and B can consume messages from the same queue.

---------------------------
HOW MULTIPLE INSTANCES WORK
---------------------------
If both System A and System B run the same Spring Boot app connected to the same RabbitMQ queue:

- RabbitMQ distributes messages **round-robin** across both consumers.
- Both systems can produce and consume messages concurrently.

If you want each system to receive **all messages** instead of round-robin distribution:

Use a **fanout exchange** configuration:

```java
@Configuration
public class RabbitConfig {

    @Bean
    public FanoutExchange fanoutExchange() {
        return new FanoutExchange("demoExchange");
    }

    @Bean
    public Queue queueA() {
        return new Queue("queueA", true);
    }

    @Bean
    public Queue queueB() {
        return new Queue("queueB", true);
    }

    @Bean
    public Binding bindQueueA(FanoutExchange fanoutExchange, Queue queueA) {
        return BindingBuilder.bind(queueA).to(fanoutExchange);
    }

    @Bean
    public Binding bindQueueB(FanoutExchange fanoutExchange, Queue queueB) {
        return BindingBuilder.bind(queueB).to(fanoutExchange);
    }
}
```
Each system listens to its own queue (queueA or queueB), and both get the same broadcasted messages.

---------------------------
TROUBLESHOOTING
---------------------------
❗ **Connection refused**
   → Check IP, firewall, and RabbitMQ listening config.

❗ **Authentication failed**
   → Verify username/password and permissions.

❗ **Queue not found**
   → Make sure your RabbitConfig bean creates it.

❗ **Can’t access 15672**
   → Ensure RabbitMQ Management plugin is enabled and firewall allows port 15672.

---------------------------
OPTIONAL ENHANCEMENTS
---------------------------
- Make queue durable: `new Queue("demoQueue", true)`
- Use `DeadLetterExchange` for error handling.
- Add `spring.rabbitmq.connection-timeout` for reliability.
- Use publisher confirms for guaranteed delivery.

===========================
END OF CANVA GUIDE
===========================

