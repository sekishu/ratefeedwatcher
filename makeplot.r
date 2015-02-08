library(ggplot2)
datestr<-format(Sys.Date()-1,"%Y%m%d")

args <- commandArgs(trailingOnly = T)

datestr=args[1]
meigara =args[2]
data<-read.csv(paste("./data/csv/",datestr,meigara,".csv",sep=""))

data$time<-strptime(data$time,"%Y-%m-%d %H:%M:%OS")+60*60*9
gg1<-qplot(y=offer-bid,x=time,data=data[data$company!="gaitame-web"&data$company!="hirose-web1",],color=company,alpha=0.5)+theme_bw()
ggsave(gg1,file=paste("./data/img/",datestr,meigara,"_full.png",sep=""),dpi=96,width=30,height=10)
gg2<-qplot(y=offer-bid,x=time,data=data[data$company!="gaitame-web"&data$company!="hirose-web1",],color=company,alpha=0.5,facets=company~.)+theme_bw()
ggsave(gg2,file=paste("./data/img/",datestr,meigara,"_each.png",sep=""),dpi=96,width=30,height=10)
gg3<-qplot(y=(offer+bid)/2,x=time,data=data[data$company!="gaitame-web"&data$company!="hirose-web1",],color=company,alpha=0.5)+theme_bw()
ggsave(gg3,file=paste("./data/img/",datestr,meigara,"_mean.png",sep=""),dpi=96,width=30,height=10)


