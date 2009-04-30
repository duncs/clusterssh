#
# NOTE: this test expects a $HOME/.perlcriticrc file containing:
#   severity  = 4
#
use Test::Perl::Critic;
all_critic_ok();
