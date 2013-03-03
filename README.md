# red.sh
**(r)emote (ed)itor (sh)ell script**

We've all been there. You SSH'd into a remote machine from your Mac and need to edit a file.

Sure you could fire up `pico` or dust off your [`vi` foo](http://vim-adventures.com), but wouldn't it be nice to run a command that opened the file in a friendly, modern GUI on the Mac in front of you? Are [BBEdit](http://www.barebones.com/products/bbedit/) and [TextWrangler](http://www.barebones.com/products/textwrangler/) friendly enough for you?

If so you're in luck because you've stumbled upon `red.sh`, a shell script that uses  the finest SSH gymnastics to accomplish exactly that.

## Install
Run the following **on the remote machine** to install `red.sh` (you don't need to install anything specific to `red.sh` on the Mac):

    curl -L http://atj.me/u/red.sh > /usr/local/bin/red.sh
    chmod +x /usr/local/bin/red.sh

## Requirements
 1. [BBEdit](http://www.barebones.com/products/bbedit/), [TextWrangler](http://www.barebones.com/products/textwrangler/) or some other App that can open sftp:// URLs installed on your Mac

 1. SSH server must be enabled on both the Mac and the remote machine. To enable the SSH server that came with your Mac, check *Remote Login* on the *Sharing* section of *System Preferences*.

 1. If you're connecting to a machine outside your firewall, you'll need to set up appropriate port forwarding on your router to forward SSH traffic trafic to your Mac's local IP (it's a shell script, not magic).

## Usage
When run over SSH, `red.sh` will attempt to detect the correct IP addresses for both the Mac and the remote machine if none are specified, so in many cases most of the arguments can be omitted.
Run the following **on the remote machine** to edit sftp://RemoteUser@RemoteHost:22//etc/hosts in BBEdit on your Mac as *User*:

    red.sh -u User /etc/hosts

Enter the password you use to log into your Mac as *User* when prompted.
    
Specify a different editor with the `-a` parameter (any App that can open sftp:// URLs should just work):

    red.sh -u User -a TextWrangler.app /etc/hosts

You can use relative paths, open multiple files at once and even use wildcard patterns:

    red.sh -u User /etc/hosts /etc/php/php.ini conf.d/*.conf

Run `red.sh` with no arguments to see all options/parameters.
 
## Suggestions
  - Use bash aliases to make convenient shortcuts. Por ejemplo, if you always log in to your Mac as *User*, maybe you'd add the following to your ~/.bash_profile on the **remote machine**:
  
        alias red='red.sh -u User'
        alias tw='red.sh -u User -a TextWrangler.app'
  
  - I recommend adding the public SSH key for your Mac user account to the remote user's ~/.ssh/authorized_keys file to prevent BBEdit/TextWrangler from prompting for the remote user's password. **This gives the Mac user account the power to access the remote machine as the remote user without being prompted for a password. You have been warned.**
  - In situations where it is safe to do so (local VMs and such), you can also prevent being prompted for your Mac password by adding the public SSH key of the user account on the remote machine to the ~/.ssh/authorized_keys file on your Mac. **This gives the remote user the power to access your Mac as you without being prompted for a password. You have been warned.**
      