#include "http_socket.h"

#include <stdbool.h>

#include <lwip/ip.h>
#include <lwip/pbuf.h>
#include <lwip/tcp.h>

#define MAX_CONCURRENT_CONNECTIONS 4

typedef struct
{
    bool in_use;

    size_t tail;
    size_t head;
} http_socket_state;

http_socket_state socket_state_pool[MAX_CONCURRENT_CONNECTIONS];
static http_socket_state *allocate_socket_state()
{
    for (int i = 0; i < MAX_CONCURRENT_CONNECTIONS; i++) {
        if (socket_state_pool[i].in_use == false) {
            return &socket_state_pool[i];
        }
    }

    return NULL;
}

static void free_socket_state(http_socket_state *state)
{
    state->in_use = false;
}

static void http_error_callback(void *arg, err_t err)
{
    http_socket_state *state = arg;
    free_socket_state(state);
}

static err_t http_sent_callback(void *arg, struct tcp_pcb *pcb, u16_t len)
{
    return ERR_MEM;
}

static err_t http_recv_callback(void *arg,
                               struct tcp_pcb *pcb,
                               struct pbuf *p,
                               err_t err)
{
    return ERR_MEM;
}

static err_t http_accept_callback(void *arg, struct tcp_pcb *pcb, err_t err)
{
    http_socket_state *state = allocate_socket_state();
    if (state == NULL) {
        sddf_printf("WEBSERVER|ACCEPT: too much connections\n");
        return ERR_MEM;
    }

    sddf_printf("WEBSERVER|ACCEPT[%s:%d]: connection accepted\n",
        ipaddr_ntoa(&pcb->remote_ip), pcb->remote_port);

    state->tail = 0;
    state->head = 0;

    tcp_nagle_disable(pcb);
    tcp_arg(pcb, state);
    tcp_sent(pcb, http_sent_callback);
    tcp_recv(pcb, http_recv_callback);
    tcp_err(pcb, http_error_callback);

    return ERR_OK;
}


void http_socket_setup()
{
    for (int i = 0; i < MAX_CONCURRENT_CONNECTIONS; i++) {
        socket_state_pool[i].in_use = false;
    }

    struct tcp_pcb *pcb = tcp_new_ip_type(IPADDR_TYPE_V4);
    if (pcb == NULL) {
        sddf_printf("WEBSERVER: could not create http socket\n");
        return;
    }

    err_t error = tcp_bind(pcb, IP_ANY_TYPE, 80);
    if (error) {
        sddf_printf("WEBSERVER: could not bind http socket: %s\n",
                    lwip_strerr(error));
        return;
    }

    pcb = tcp_listen_with_backlog_and_err(pcb, 1, &error);
    if (error) {
        sddf_printf("WEBSERVER: could not listen on http socket: %s\n",
                    lwip_strerr(error));
    }

    tcp_accept(pcb, http_accept_callback);
}
