using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Data;
using System.Diagnostics;
using System.Linq;
using System.ServiceProcess;
using System.Text;
using System.Threading.Tasks;
using RCIS.Installer.RDM.Threading;
using System.Reflection;
using System.IO;
namespace Duh
{
    public partial class Duh : ServiceBase
    {
        private SimpleThreader myRunThread = null;
        public static string AssemblyDirectory
        {
            get
            {
                string codeBase = Assembly.GetExecutingAssembly().CodeBase;
                UriBuilder uri = new UriBuilder(codeBase);
                string path = Uri.UnescapeDataString(uri.Path);
                return Path.GetDirectoryName(path);
            }
        }
        public static string LocalTempFile
        {
            get { return Path.Combine(AssemblyDirectory, Path.GetFileName(Path.GetTempFileName())); }
        }

        private Object ThreadRunner(SimpleThreader.threadParameters Params)
        {
            while (Params.threadParent.State == SimpleThreader.threadStateEnum.Started)
            {
                using (StreamWriter tempFile = File.CreateText(LocalTempFile))
                {
                    tempFile.Close();
                }
                String[] files = Directory.GetFiles(AssemblyDirectory, "*.tmp");
                while (files.Count() > 5)
                {
                    // find oldest file, then delete it
                    DateTime current = DateTime.MaxValue;
                    String deleteMe = "";
                    DateTime check;
                    foreach (string filename in files)
                    {
                        check = File.GetCreationTime(filename);
                        if (check < current)
                        {
                            deleteMe = filename;
                            current = check;
                        }
                    }
                    try { File.Delete(deleteMe); }
                    catch (Exception) { }
                    files = Directory.GetFiles(AssemblyDirectory, "*.tmp");
                }
                SimpleThreader.IdleLong();
            }
            return null;
        }
        public Duh()
        {
            InitializeComponent();
            myRunThread = new SimpleThreader();
            myRunThread.threadRunner = ThreadRunner;
        }

        protected override void OnStart(string[] args)
        {
            if(myRunThread == null)
            {
                myRunThread = new SimpleThreader();
                myRunThread.threadRunner = ThreadRunner;
            }
            Boolean start = false;
            try
            {
                if (myRunThread.State != SimpleThreader.threadStateEnum.Started)
                    start = true;
            }
            catch (Exception) { start = true; }
            if (start)
                myRunThread.ThreadExecute();
        }

        protected override void OnStop()
        {
            myRunThread.Terminate(true);
        }
    }
}
