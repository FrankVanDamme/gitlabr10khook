# Class: gitlabr10khook::install
# vim: set softtabstop=2 ts=2 sw=2 expandtab:
# ===========================
#
# This configures the gitlab-puppet-webhook that will take
# webhook triggers from gitlab and run r10k on your puppet server
# it currently only supports the PUSH mechanism
#
# Authors
# -------
# Karl Vollmer <karl.vollmer@gmail.com>
# Copyright
# ---------
# Copyright 2016 Karl Vollmer
class gitlabr10khook::install inherits gitlabr10khook {

  # We're going to need OpenSSL and various other Python packages
  # For now we're going to assume they got them all, needs to be
  # Corrected, and allow for different OS's
  ensure_packages($gitlabr10khook::install_deps,{'ensure'=>'present'})

  Exec {
    path => "/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/opt/puppetlabs/bin",
  }

  ## Checkout the Gitlab Puppet webhook
  $vcsrepo_user = $gitlabr10khook::server['user'] ? {
    undef   => 'root',
    default => $gitlabr10khook::server[user],
  }
  notify {"vcsrepo_user: $vcsrepo_user":}

  vcsrepo { 'gitlabr10khook-checkout-from-gitlab':
    ensure   => present,
    provider => git,
    user     => 'root',
    owner    => $vcsrepo_user,
    path     => "${gitlabr10khook::install}",
    source   => 'https://github.com/vollmerk/gitlab-puppet-webhook.git',
    revision => "${gitlabr10khook::release}",
  }

  if ( $::operatingsystem == 'Debian' and versioncmp( $::operatingsystemrelease , '9.0' ) >= 0 ){
    package { [ "python-pip" ]:
      ensure => installed,
      before => Package['gitlabr10khook-slackweb'],
    }
    # python-daemon's version in Debian 9 is 2.1.2
    # For Debian 8, you may want to use jessie-backports
    package { [ "python-daemon"]:
      ensure  => installed,
      require => Package['python-pip'],
    }
    package  { 'gitlabr10khook-psutil':
      name    => 'python-psutil',
      ensure  => installed,
      require => Package['python-pip'],
    }

  } else { # Red Hat and friends

    exec { 'gitlabr10khook-pip':
      command     => 'easy_install pip',
      user        => 'root',
      require     => [ Package['python'], Vcsrepo['gitlabr10khook-checkout-from-gitlab'] ],
      before      => Package['gitlabr10khook-slackweb'],
    }
    ## Upgrade Python-Daemon so it works
    package { "python-daemon":
      ensure   => latest,
      provider => pip,
      require  => Exec['gitlabr10khook-pip'],
    }
    package { 'gitlabr10khook-psutil':
      name     => 'psutil',
      provider => pip,
      ensure   => latest,
      require  => Exec['gitlabr10khook-pip'],
    }
  }

  # PSutil requires gcc to compile, so if we took responsibility over getting
  # it installed, we have to require that package
  if (defined (Package['gcc'])){
    Package['gcc'] -> Package['gitlabr10khook-psutil']
  }
  if (defined (Package["${gitlabr10khook::python_dev}"])){
    Package["${gitlabr10khook::python_dev}"] -> Package['gitlabr10khook-psutil']
  }

  package { 'gitlabr10khook-slackweb':
    name     => 'slackweb',
    provider => pip,
    ensure   => latest
  }
}
