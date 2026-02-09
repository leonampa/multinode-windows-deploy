# Project: Semi-Automated Multi-Node Windows Deployment

# **Introduction**

Hello! My name is Leo, I'm 16, and I'm the IT Administrator at my school.

# **The project, in short**

* **What sparked it?** Upgrading equipment (sponsorship)
* **Why did I start?** Previous equipment inoperable, with perfectly functional equipment gathering dust in a closet.
* **What’s the goal?** Use 12x PCs that were left over from before the sponsorship took place, and utilize them effectively where they are needed (teacher’s lounge), on a zero budget.
* **How did I do it?** I took one of the PCs, made a “role model” I wanted the other PCs to be like (aka, “Golden Image”), and copied it over with a custom script.
* **Stack?** Windows Server 2019, DISM, Batch Scripting, Sysprep, PXE/WDS, WinPE.

# **Backstory**

Our school's computer lab consisted of 12x ThinkCentre M75s Gen 2 Desktop computers [[📷]](https://github.com/leonampa/multinode-windows-deploy/blob/main/the-thinkcentres-in-question.jpg). On the 31st March and the 1st April of 2025, our school was selected to participate in the Programme for International Student Assessment (PISA), so we received newer computers, for students to use to participate in the programme. As such, the higher-end laptops replaced the desktops entirely, and all eight desktops had been sitting in our computer lab’s closet. Meanwhile, the rest of the school's computer infrastructure was poor, with the teachers’ lounge having only three barely functioning computers, in stark contrast to the thirty-two teachers working full-time or part-time at the school. Hence, I took initiative, and used nine of the then-useless desktops, and deployed eight pieces to the teacher's lounge to replace the aforementioned barely working three computers there, and one piece to the science laboratory, to replace the equally severely outdated computer there.

# **Phase A: What OS should I deploy, and how?**

## **A.1: What OS, and why?**

The computers, before being replaced, ran Windows 10 x64, slow enough to cause frustration to the students, and hindered educators’ attempts to teach effectively. I tried to completely reinstall the OS, Windows 10 Pro x64, but the speed difference was negligible, since the hardware remained the same. We didn't have the budget (or, *any* budget) to upgrade the computers from their HDDs to faster SSDs, so, the only choice was downgrading the OS. Windows 7 is incompatible with most modern applications, and Linux is out of the question, considering how,

1. most teachers barely know how to use Windows at all,
2. having Office on every computer is crucial, with alternatives being limited and often problematic with backwards compatibility, and
3. needing something that just works, with little maintenance required, or maintenance that could be performed by someone with a non-technical background.

So, I opted for the vastly underappreciated Windows 8.1 x64, for its performance, compatibility with Office 2016, and similarity to Windows 10’s UI. Even though Windows 8.1 has been EOL since the 10th January 2023, strategically, it's a better fit considering the equipment I'm working with. It's far better to have an outdated, but functional machine, rather than an up-to-date, but unusable one. Replacing unusable machines with more, fancier looking, unusable machines, defeats the purpose.

## **A.2: How did I get the image to be deployed?**

I moved a single computer down, plugged it into the wall, and started the process of making the “Golden PC” image, the image that was deployed to the rest of the computers. I got the ISO off [https://os.click](https://os.click), flashed it on a flash drive (which will be referenced to from now on as “Installer”), installed Windows 8.1 on the computer, then set up a local account, disabled automatic updates, and installed 7-Zip, AnyDesk, Avast, Chrome, Foxit PDF Reader, Notepad++, Office 2016 and VLC, using Ninite, and mapped the school's Samba server to a letter drive.

With the set up part out of the way, it was time to get the image out of the computer, and into a .wim file (Windows Imaging Format, file-based disk image format developed by Microsoft for efficient deployment of Windows OSes). But first, I had to generalize the installation, to not include unique, machine-specific information like the Security Identifier (SID), computer name, and installed drivers on the file. That can be done with the command:  
~~~
sysprep /generalize /shutdown  
~~~

After that's done, I booted into the Installer flash drive again (it's CRUCIAL to not boot into the Windows/Golden Image drive again, as that would initialize the OOBE experience), pressed Shift + F10 to access the Command Prompt, and ran:



~~~
diskpart  
list disk  
list volume (to identify drive letters - from now on, D:, and all flash drives containing the .wim file later on, are “Image” flash drives. It's important for the flash drive to be exFAT or NTFS, not FAT32, due to the 4GB file restriction)  
exit  
dism /Capture-Image /ImageFile:D:\\install.wim /CaptureDir:C:\\ /Name:GoldenImage  
~~~

And after that, I shut down the PC, and set it aside.

NOTE: You can bypass A.3, Step 8, and a tedious part of the deployment process, by setting up an unattend.xml file, if you add the argument /Apply-Unattend:<path\_to\_unattend.xml>

## **A.3: How will I deploy the Golden Image to the computers?**

I had to deploy the .wim file to the computers, and I needed a quick, low effort way to do so. I boot off the Installer flash drive, open the command prompt, and run deploy.bat, available in the GitHub repository. After a LOT of back and forth with Gemini 3, I reached the final version of the deploy.bat file that, when run, it

1. Exits diskpart
2. Runs list disk (to identify the drive for Windows to be deployed to)
3. Exits diskpart
4. Asks for the number of the disk for Windows to be deployed to
5. Asks the drive letter of the disk with the .wim file
6. Makes the three necessary partitions for Windows to run (EFI, MSR, Windows)
7. Deploys Windows to the Windows partition
8. Reboots the computer to the OOBE environment, where it asks for UI color, PC name, user name (WARNING, this makes a second user. The first user I made is still there. I personally name the second, made-on-OOBE, user “deleteme”, enter the first, made-on-installation user, and delete “deleteme”.), and Windows tries to connect to the internet for me to log in with a Microsoft account. (I just pull the Ethernet jack off until I reach a desktop)

The moment it reboots to OOBE, I pull out the Image and Installer flash drives.

After that's done, I go to the user (made-on-installation), delete the deleteme user, and activate Windows and Office.  
And that's it! I repeat A.3 for every PC I want to deploy. I, personally, keep the two files (deploy.bat and install.wim) on my toolkit any time, since they're useful for reviving old PCs.

# **Phase B: What do I do for more PCs?**

I, unfortunately, don't have that many flash drives to mass deploy each PC individually, since per PC, it takes up one Installer, and one Image flash drive. So, instead, I grabbed one of the older PCs in the computer lab's closet, an HP EliteDesk, installed Windows Server 2019 on it, and set up a PXE server, like this.

## **B.1: Required Equipment (where X, the number of targets/PCs you want to deploy at a time)**

* \[ ] Router (it doesn't have to be connected to the internet, you can just use any old router, so long as it has Ethernet ports. It's more reliable with DHCP than Windows Server in my experience)
* \[ ] Ethernet switch, with X+2 ports (for the server and a router. Might not need it if you have X+1 ports on your router)
* \[ ] Monitor, keyboard, mouse
* \[ ] X Image flash drives
* \[ ] X+1 Ethernet cables (if you have only one target, 1)
* \[ ] X+2 Power cables (if you have only one target, 2)
* \[ ] 1 Display cable (HDMI, VGA, etc)
* \[ ] Power strip with X+2 ports (for the server, and the monitor) (optional)

## **B.2: Set-up**

1. Install Windows Server 2019, and reach the desktop, while still having the installation media connected to the computer (important!)
2. Open Server Manager
3. Go to the top right corner, under Manage > Add Roles and Features
4. Press “Next >” three times
5. In the Select server roles window, check Windows Deployment Services
6. Press Add Features
7. Press “Next >” three times
8. Press Install, wait for the installation to finish, then press Close
9. Hook up all four targets and the server to the power
10. Hook up all four targets and the server to the same Ethernet switch
11. Go to the top right corner, under Tools > Windows Deployment Services
12. Press Servers, right-click your computer, and press Configure Server
13. Press “Next >”
14. In Install Options, select Standalone server, and then “Next >” twice
15. Press Yes
16. In PXE Server Initial Settings, select “Respond to all client computers (known and unknown), then “Next >”
17. Press “Finish”
18. On the new window (Add Image Wizard), press browse, and navigate to (WS2019 Installation Media):/sources, and select it. Press OK, then “Next >” three times, then Finish.

## **B.3: Deploying**

1. Connect the target to the display
2. Plug in one of the Image flash drives
3. Power the target on, and interrupt the boot sequence to access the BIOS/UEFI boot menu. (F12, for most)
4. Choose PXE Boot/LAN
5. Follow the process (if any) to reach the purple Windows Deployment Services installation screen (have your finger ready on the F12 button, most computers need you to press
6. Press Shift + F10 to access the Command Prompt
7. CD to the Image flash drive, run the script and follow the instructions
8. Wait
9. Set up Windows (if not using unattend.xml)
10. Rinse and repeat

## **B.4: Pros and Cons:**

The advantage of this method is that you can scale deployment to more targets for cheaper (1 flash drive and one Ethernet cable extra, instead of two flash drives extra), and to more people (with another monitor, keyboard and mouse - the server remains the same, just more computers plug into it via the switch/router). Additionally, you can skip the flash drives entirely, if you share the .wim file over Samba from the server, at the considerable sacrifice of speed decreasing as targets connect, running more commands from the keyboard, facing potential issues with connectivity, and bringing down your entire network's performance, if connected to your LAN.

The disadvantage of this method is that you need an additional PC, or to use one of your future targets temporarily as a deployer, and then using the manual method as described on A.3), and it takes more time to get going.

# **Phase C: Looking back at the project in hindsight**

## **C.1: What came out of it, though?**

I started this process on Monday morning, I finished deploying the last computer on Thursday noon, and installed all the computers by Friday noon, all the work being done in breaks between classes, and empty periods in my schedule.  
Within a single week, the entire teachers office got upgraded, streamlining all processes involving computers, increasing use, decreasing hassle, and creating opportunities for teachers to effectively and efficiently plan and prepare for their classes. The dreaded “I have to print out flyers”, in fear of the computer's lag and buffering, and the queue of teachers trying to do the same thing, shifted to all teachers having one more thing off their minds, and a more harmonic workplace for everyone, all grateful for the change and amazed by the speed of the deployment period.  
Additionally, once I finish my studies and leave the school, the staff wouldn’t necessarily need me to replace a malfunctioning computer. There’s three, identical computers, hardware and software wise, available in the computer lab’s closet, ready to be installed or hot-swapped anywhere they become necessary.

## **C.2: What could I have done differently?**

1. I could have set up an unattend.xml file to set up the user accounts, as mentioned under A.3, Step 8, to shorten the amount of time spent over a keyboard for each target.
2. I could have shared the .wim file over Samba from the server computer, as mentioned in B.4, Cons, to use up less flash drives, but network uptime and reliability, along with speed of deployment, were factors more important to me than not having a spare flash drive for the few days it took to set this up.
