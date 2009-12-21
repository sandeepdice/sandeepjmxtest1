package myjmx;

import javax.management.*;
import java.lang.management.*;
import javax.management.remote.*;

public class SimpleAgentRMI {
   private MBeanServer mbs = null;

   public SimpleAgentRMI() {

      // Get the platform MBeanServer
      mbs = ManagementFactory.getPlatformMBeanServer();

      // Unique identification of MBeans
      Hello helloBean = new Hello();
      ObjectName helloName = null;

      try {
         // Uniquely identify the MBeans and register them with the MBeanServer 
         helloName = new ObjectName("SimpleAgentRMI:name=hellothere");
         mbs.registerMBean(helloBean, helloName);

         // Create an RMI connector and start it
         JMXServiceURL url = new JMXServiceURL("service:jmx:rmi:///jndi/rmi://localhost:9999/server");
         JMXConnectorServer cs = JMXConnectorServerFactory.newJMXConnectorServer(url, null, mbs);
         cs.start();
      } catch(Exception e) {
         e.printStackTrace();
      }
   }

   public static void main(String argv[]) {
      SimpleAgentRMI agent = new SimpleAgentRMI();
      System.out.println("SimpleAgent is running...");
   }
}
