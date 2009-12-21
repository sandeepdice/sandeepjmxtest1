package myjmx;
import javax.management.*;
import java.lang.management.*;
import com.sun.jdmk.comm.HtmlAdaptorServer;

public class SimpleAgentHtml {


	   private MBeanServer mbs = null;

	   public SimpleAgentHtml() {

	      // Create an MBeanServer and HTML adaptor (J2SE 1.4)
	      mbs = ManagementFactory.getPlatformMBeanServer();
	      HtmlAdaptorServer adapter = new HtmlAdaptorServer();

	      // Unique identification of MBeans
	      Hello helloBean = new Hello();
	      ObjectName adapterName = null;
	      ObjectName helloName = null;

	      try {
	         // Uniquely identify the MBeans and register them with the MBeanServer 
	         helloName = new ObjectName("SimpleAgentHtml:name=hellothere");
	         mbs.registerMBean(helloBean, helloName);
	         // Register and start the HTML adaptor
	         adapterName = new ObjectName("SimpleAgent:name=htmladapter,port=8000");
	         adapter.setPort(8000);
	         mbs.registerMBean(adapter, adapterName);
	         adapter.start();
	      } catch(Exception e) {
	         e.printStackTrace();
	      }
	   }

	   public static void main(String argv[]) {
	      SimpleAgentHtml agent = new SimpleAgentHtml();
	      System.out.println("SimpleAgentHtml is running...");
	   }
	}

