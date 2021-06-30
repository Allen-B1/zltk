void alt_FD_CLR(int fd, fd_set *set) {
    FD_CLR(fd, set);
}
int  alt_FD_ISSET(int fd, fd_set *set) {
    return FD_ISSET(fd, set);
}
void alt_FD_SET(int fd, fd_set *set) {
     FD_SET(fd, set);
}
void alt_FD_ZERO(fd_set *set) {
     FD_ZERO(set);
}